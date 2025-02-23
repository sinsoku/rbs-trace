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
        @void_types[key] = void?(node)

        visit_child_nodes(node)
      end

      (Prism::Visitor.instance_methods.grep(/^visit_/) - instance_methods).each do |m|
        alias_method(m, :visit_child_nodes)
      end

      private

      # @rbs (Prism::CallNode) -> bool
      def void?(node)
        parent_node = @parents[-1]
        next_parent_node = @parents[-2]
        return true if parent_node.nil? || next_parent_node.nil?

        if next_parent_node.type == :program_node
          parent_node.type == :statements_node
        else
          parent_node.type == :statements_node && parent_node.child_nodes[-1] != node
        end
      end
    end
  end
end
