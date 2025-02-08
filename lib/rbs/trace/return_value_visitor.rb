# frozen_string_literal: true

module RBS
  class Trace
    class ReturnValueVisitor < Prism::BasicVisitor
      class << self
        # @rbs (String) -> ReturnValueVisitor
        def parse_file(path)
          new.tap do |visitor|
            result = Prism.parse_file(path)
            visitor.visit(result.value)
          end
        end
      end

      # @void_types: Hash[Array[Integer, Symbol], bool]
      # @parents: Array[Prism::Node]

      # @rbs () -> void
      def initialize
        @void_types = {} #: Hash[Array[Integer|Symbol], bool]
        @parents = [] #: Array[Prism::Node]
        super
      end

      # @rbs (Integer, Symbol) -> bool
      def void_type?(lineno, name)
        @void_types.fetch([lineno, name], false)
      end

      # @rbs (Prism::Node) -> void
      def visit_child_nodes(node)
        @parents.push(node)
        super
        @parents.pop
      end

      # @rbs (Prism::CallNode) -> void
      def visit_call_node(node)
        key = [node.location.start_line, node.name]
        @void_types[key] = !use_return_value?(node)

        visit_child_nodes(node)
      end

      (Prism::Visitor.instance_methods.grep(/^visit_/) - instance_methods).each do |m|
        alias_method(m, :visit_child_nodes)
      end

      private

      # @rbs (Prism::CallNode) -> bool
      def use_return_value?(_node)
        parent_type = @parents[-1]&.type
        next_parent_type = @parents[-2]&.type

        parent_type.end_with?("write_node") ||
          parent_type == :call_node ||
          (parent_type == :statements_node && next_parent_type == :embedded_statements_node)
      end
    end
  end
end
