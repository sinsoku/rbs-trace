# frozen_string_literal: true

module RBS
  module Trace
    class MethodTracing # rubocop:disable Metrics/ClassLength
      ASSIGNED_NODE_TYPES = %i[statements_node local_variable_write_node instance_variable_write_node
                               class_variable_write_node constant_write_node call_node
                               embedded_statements_node].freeze #: Array[Symbol]
      private_constant :ASSIGNED_NODE_TYPES

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
      def insert_rbs
        files.each_value(&:rewrite)
      end

      private

      # @rbs () -> TracePoint
      def trace
        @trace ||= TracePoint.new(:call, :return) { |tp| record(tp) }
      end

      # @rbs () -> Environment
      def env
        @env ||= Environment.new
      end

      # @rbs () -> Logger
      def logger
        return @logger if defined?(@logger)

        level = ENV["RBS_TRACE_DEBUG"] ? :debug : :info
        @logger = Logger.new($stdout, level:)
      end

      # @rbs () -> Array[Declaration]
      def stack_traces
        @stack_traces ||= []
      end

      # @rbs (String) -> File
      def find_or_new_file(path)
        files[path] ||= File.new(path, env)
      end

      # @rbs () -> Builder
      def builder
        @builder ||= Builder.new
      end

      # @rbs (TracePoint) -> void
      def record(tp) # rubocop:disable Metrics/MethodLength
        return if ignore_path?(tp.path)

        file = find_or_new_file(tp.path)
        member = file.find_or_new_method_def_decl(
          klass: tp.defined_class,
          name: tp.method_id,
        )

        case tp.event
        when :call
          call_event(tp)
        when :return
          return_event(tp, member)
        end
      rescue StandardError => e
        logger.debug(e)
      end

      # @rbs (TracePoint) -> void
      def call_event(tp) # rubocop:disable Metrics
        method_type = builder.parse_method_parameters(tp.binding, tp.parameters)
        return_type = builder.type_void unless assign_return_value?(tp.path, tp.method_id)

        stack_traces << [method_type, return_type]
      end

      # @rbs (TracePoint, AST::Members::MethodDefinition) -> void
      def return_event(tp, member)
        method_type, return_type = stack_traces.pop
        # TODO: check usecase where method_type is nil
        return unless method_type

        type = return_type || builder.parse_object(tp.return_value)
        new_type = method_type.type.with_return_type(type)
        method_type = method_type.update(type: new_type) # rubocop:disable Style/RedundantSelfAssignment
        return if member.overloads.include?(method_type)

        # TODO: Check for problems with mutable operations
        member.overloads << method_type
      end

      # @rbs (String) -> bool
      def ignore_path?(path)
        bundle_path = Bundler.bundle_path.to_s # steep:ignore UnknownConstant
        ruby_lib_path = RbConfig::CONFIG["rubylibdir"]

        path.start_with?("<internal") ||
          path.start_with?("(eval") ||
          path.start_with?(bundle_path) ||
          path.start_with?(ruby_lib_path) ||
          path.start_with?(__FILE__)
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
end
