# frozen_string_literal: true

module RBS
  module Trace
    class MethodTracing # rubocop:disable Metrics/ClassLength
      ASSIGNED_NODE_TYPES = %i[statements_node local_variable_write_node instance_variable_write_node
                               class_variable_write_node constant_write_node call_node embedded_statements_node].freeze
      private_constant :ASSIGNED_NODE_TYPES

      def enable(&)
        trace.enable(&)
      end

      def disable
        trace.disable
      end

      def files
        @files ||= {}
      end

      def insert_rbs
        files.each_value(&:rewrite)
      end

      private

      def trace
        @trace ||= TracePoint.new(:call, :return, :raise) { |tp| record(tp) }
      end

      def logger
        return @logger if defined?(@logger)

        level = ENV["RBS_TRACE_DEBUG"] ? :debug : :info
        @logger = Logger.new($stdout, level:)
      end

      def stack_traces
        @stack_traces ||= []
      end

      def find_or_new_file(path)
        files[path] ||= File.new(path)
        files[path]
      end

      def find_or_new_definition(file, tp)
        name = tp.method_id
        is_singleton = tp.defined_class.singleton_class?
        klass = is_singleton ? tp.self : tp.defined_class
        mark = is_singleton ? "." : "#"
        signature = "#{klass}#{mark}#{name}"

        _filename, lineno = tp.self.method(name).source_location
        file.definitions[signature] ||= Definition.new(klass:, name:, lineno:)
      end

      def record(tp) # rubocop:disable Metrics/MethodLength
        return if ignore_path?(tp.path)

        file = find_or_new_file(tp.path)
        definition = find_or_new_definition(file, tp)

        case tp.event
        when :call
          call_event(tp)
        when :return, :raise
          return_event(tp, definition)
        end
      rescue StandardError => e
        logger.debug(e)
      end

      def call_event(tp) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        parameters = tp.parameters.map do |kind, name|
          value = tp.binding.local_variable_get(name)
          klass = case kind
                  when :rest
                    value.map(&:class).uniq
                  when :keyrest
                    value.map { |_, v| v.class }.uniq
                  when :block
                    # TODO: support block argument
                  else
                    [value.class]
                  end
          [kind, name, klass]
        end
        stack_traces << Declaration.new(parameters, void: !assign_return_value?(tp.path, tp.method_id))
      end

      def return_event(tp, definition)
        decl = stack_traces.pop
        # TODO: check usecase where decl is nil
        return unless decl

        decl.return_type = tp.event == :return ? [tp.return_value.class] : [nil]
        definition.decls << decl
      end

      def ignore_path?(path)
        bundle_path = Bundler.bundle_path.to_s
        ruby_lib_path = RbConfig::CONFIG["rubylibdir"]

        path.start_with?("<internal") ||
          path.start_with?("(eval") ||
          path.start_with?(bundle_path) ||
          path.start_with?(ruby_lib_path) ||
          path.start_with?(__FILE__)
      end

      def assign_return_value?(path, method_id) # rubocop:disable Metrics
        is_initialize = method_id == :initialize
        return false if is_initialize

        i = caller_locations.index { |loc| loc.path == path && loc.label == method_id.to_s }
        loc = caller_locations[i + 1]

        node = parsed_nodes(loc.path)
        method_name = is_initialize ? :new : method_id
        parents = find_parents(node, method_name:, lineno: loc.lineno)
        return false unless parents

        parent = parents[1]
        ASSIGNED_NODE_TYPES.include?(parent.type)
      end

      def find_parents(node, method_name:, lineno:, parents: [])
        result = nil
        node.compact_child_nodes.each do |child|
          break if result

          found = child.type == :call_node && child.name == method_name && child.location.start_line == lineno
          result = found ? [child, *parents] : find_parents(child, method_name:, lineno:, parents: [node, *parents])
        end
        result
      end

      def parsed_nodes(path)
        @parsed_nodes ||= {}
        @parsed_nodes[path] ||= Prism.parse_file(path)
        @parsed_nodes[path].value
      end
    end
  end
end
