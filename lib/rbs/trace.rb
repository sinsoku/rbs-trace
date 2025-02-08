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
    PATH_INTERNAL = "<internal" #: String
    PATH_EVAL = "(eval" #: String
    PATH_INLINE_TEMPLATE = "inline template" #: String

    private_constant :BUNDLE_PATH, :RUBY_LIB_PATH, :PATH_INTERNAL, :PATH_EVAL, :PATH_INLINE_TEMPLATE

    # @rbs (?log_level: Symbol, ?raises: bool) -> void
    def initialize(log_level: nil, raises: false)
      @log_level = log_level
      @log_level ||= ENV["RBS_TRACE_DEBUG"] ? :debug : :info
      @raises = raises
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
      return if ignore_path?(tp.path)

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
             !assign_return_value?(tp.path, tp.method_id)

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

    # @rbs (String) -> bool
    def ignore_path?(path)
      path.start_with?(
        PATH_INTERNAL,
        PATH_EVAL,
        PATH_INLINE_TEMPLATE,
        BUNDLE_PATH,
        RUBY_LIB_PATH,
        __FILE__
      )
    end

    # @rbs (String, Symbol) -> bool
    def assign_return_value?(path, method_id) # rubocop:disable Metrics
      return false if method_id == :initialize

      locations = caller_locations || []
      i = locations.index { |loc| loc.path == path && loc.label == method_id.to_s }
      loc = locations[i + 1] if i
      # If the caller is not found, assume the return value is used.
      return true unless loc

      path = loc.path.to_s
      # If the file does not exist, it cannot be parsed and returns false.
      return false unless ::File.exist?(path)

      @return_value_visitors ||= {} #: Hash[String, ReturnValueVisitor]
      v = @return_value_visitors.fetch(path) { ReturnValueVisitor.parse_file(path) }
      !v.void_type?(loc.lineno, method_id)
    end
  end
end
