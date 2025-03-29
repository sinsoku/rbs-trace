# frozen_string_literal: true

require "bundler"
require "logger"
require "optparse"
require "prism"
require "rbs"

require_relative "trace/helpers"
require_relative "trace/builder"
require_relative "trace/cli"
require_relative "trace/cli/inline"
require_relative "trace/cli/merge"
require_relative "trace/file"
require_relative "trace/inline_comment_visitor"
require_relative "trace/overload_compact"
require_relative "trace/return_value_visitor"
require_relative "trace/version"

module RBS
  class Trace
    class Error < StandardError; end
    # steep:ignore:start
    BUNDLE_PATH = Bundler.bundle_path.to_s #: String
    # steep:ignore:end
    RUBY_LIB_PATH = RbConfig::CONFIG["rubylibdir"] #: String

    private_constant :BUNDLE_PATH, :RUBY_LIB_PATH

    # @rbs (?log_level: Symbol, ?raises: bool) -> void
    def initialize(log_level: nil, raises: false)
      @log_level = log_level
      @log_level ||= ENV["RBS_TRACE_DEBUG"] ? :debug : :info
      @raises = raises
      @trace_paths = Set.new(Dir.glob("**/*.rb").reject { |path| path.start_with?(BUNDLE_PATH, RUBY_LIB_PATH) })
    end

    # @rbs [T] () { () -> T } -> T
    def enable(&)
      trace.enable(&)
    end

    # @rbs () -> void
    def disable
      trace.disable
    end

    # @rbs () -> Hash[String, File]
    def files
      @files ||= {}
    end

    # @rbs () -> void
    def save_comments
      files.each_value(&:rewrite)
    end

    # @rbs (out_dir: String) -> void
    def save_files(out_dir:)
      files.each_value { |file| file.save_rbs(out_dir) }
    end

    private

    # @rbs () -> TracePoint
    def trace
      @trace ||= TracePoint.new(:call, :return) { |tp| record(tp) }
    end

    # @rbs () -> Logger
    def logger
      @logger ||= Logger.new($stdout, level: @log_level)
    end

    # @rbs () -> Builder
    def builder
      @builder ||= Builder.new
    end

    # @rbs (String) -> File
    def find_or_new_file(path)
      files[path] ||= File.new(path)
    end

    # @rbs (TracePoint) -> void
    def record(tp) # rubocop:disable Metrics/MethodLength
      return unless @trace_paths.include?(tp.path)

      file = find_or_new_file(tp.path)
      # steep:ignore:start
      member = file.find_or_new_method_definition(tp.self, tp.defined_class, tp.method_id)
      # steep:ignore:end
      return unless member

      case tp.event
      when :call
        call_event(tp, member)
      when :return
        return_event(tp, member)
      end
    rescue StandardError => e
      logger.debug(e)
      raise(e) if @raises
    end

    # @rbs (TracePoint, AST::Members::MethodDefinition) -> void
    def call_event(tp, member)
      # steep:ignore:start
      void = member.overloads.all? { |overload| overload.method_type.type.return_type.is_a?(Types::Bases::Void) } &&
             void_return_type?(tp.path, tp.method_id)

      builder.method_call(
        bind: tp.binding,
        parameters: tp.parameters,
        void:
      )
      # steep:ignore:end
    end

    # @rbs (TracePoint, AST::Members::MethodDefinition) -> void
    def return_event(tp, member)
      overload = builder.method_return(tp.return_value)
      return if member.overloads.include?(overload)

      member.overloads << overload
    end

    # @rbs (String, Symbol) -> bool
    def void_return_type?(path, method_id)
      return true if method_id == :initialize

      loc = find_caller_location(path, method_id.to_s)
      # If the caller is not found, assume the return value is used.
      return false unless loc

      caller_path = loc.path.to_s
      # Returns true if the file does not exist (eval, etc.)
      return true unless ::File.exist?(caller_path)

      # If the file is not Ruby, assume the return value is used. (erb, haml, etc.)
      return false if ::File.extname(caller_path) != ".rb"

      @return_value_visitors ||= {} #: Hash[String, ReturnValueVisitor]
      v = @return_value_visitors.fetch(caller_path) { ReturnValueVisitor.parse_file(caller_path) }
      v.void_type?(loc.lineno, method_id)
    end

    # @rbs (String, String) -> Thread::Backtrace::Location?
    def find_caller_location(path, label)
      locations = caller_locations || []
      i = locations.index { |loc| loc.path == path && loc.label == label }
      locations[i + 1] if i
    end
  end
end
