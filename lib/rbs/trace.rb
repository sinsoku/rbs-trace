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
require_relative "trace/version"

module RBS
  class Trace # rubocop:disable Metrics/ClassLength
    class Error < StandardError; end

    ASSIGNED_NODE_TYPES = %i[statements_node local_variable_write_node instance_variable_write_node
                             class_variable_write_node constant_write_node call_node
                             embedded_statements_node].freeze #: Array[Symbol]
    # steep:ignore:start
    BUNDLE_PATH = Bundler.bundle_path.to_s #: String
    # steep:ignore:end
    RUBY_LIB_PATH = RbConfig::CONFIG["rubylibdir"] #: String
    PATH_INTERNAL = "<internal" #: String
    PATH_EVAL = "(eval" #: String
    PATH_INLINE_TEMPLATE = "inline template" #: String

    private_constant :ASSIGNED_NODE_TYPES, :BUNDLE_PATH, :RUBY_LIB_PATH, :PATH_INTERNAL, :PATH_EVAL,
                     :PATH_INLINE_TEMPLATE

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

    # @rbs (BasicObject) -> Class
    def obj_to_class(obj)
      Object.instance_method(:class).bind_call(obj)
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
      is_initialize = method_id == :initialize
      return false if is_initialize

      locations = caller_locations || []
      i = locations.index { |loc| loc.path == path && loc.label == method_id.to_s }
      loc = locations[i + 1] if i
      # If the caller is not found, assume the return value is used.
      return true unless loc

      node = parsed_nodes(loc.path) # steep:ignore ArgumentTypeMismatch
      return false unless node

      method_name = is_initialize ? :new : method_id
      parents = find_parents(node, method_name:, lineno: loc.lineno)
      return false unless parents

      parent = parents[1]
      ASSIGNED_NODE_TYPES.include?(parent.type) # steep:ignore NoMethod
    end

    # @rbs (Prism::Node, method_name: Symbol, lineno: Integer, ?parents: Array[Prism::Node]) -> Array[Prism::Node]?
    def find_parents(node, method_name:, lineno:, parents: [])
      result = nil
      node.compact_child_nodes.each do |child| # steep:ignore NoMethod
        break if result

        found = child.type == :call_node && child.name == method_name && child.location.start_line == lineno
        result = found ? [child, *parents] : find_parents(child, method_name:, lineno:, parents: [node, *parents])
      end
      result
    end

    # @rbs (String) -> Prism::ProgramNode?
    def parsed_nodes(path)
      return unless ::File.exist?(path)

      @parsed_nodes ||= {} #: Hash[String, Prism::ParseResult]
      @parsed_nodes[path] ||= Prism.parse_file(path)
      @parsed_nodes[path].value
    end
  end
end
