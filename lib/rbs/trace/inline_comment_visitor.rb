# frozen_string_literal: true

module RBS
  class Trace
    class InlineCommentVisitor < Prism::Visitor
      # @rbs (Hash[TypeName, AST::Declarations::t], Hash[Integer, String]) -> void
      def initialize(decls, comments)
        @decls = decls
        @comments = comments
        @context = [] #: Array[Symbol]

        super()
      end

      # @rbs override
      # @rbs (Prism::Node) -> void
      def visit_class_node(node)
        with_context node do
          super
        end
      end

      # @rbs override
      # @rbs (Prism::Node) -> void
      def visit_module_node(node)
        with_context node do
          super
        end
      end

      # @rbs override
      # @rbs (Prism::Node) -> void
      def visit_def_node(node)
        member = find_method_definition(node.name)
        if member
          lineno = node.location.start_line - 1
          indent = " " * node.location.start_column
          overloads = OverloadCompact.new(member.overloads).call
          comment = overloads.map(&:method_type).join(" | ")

          @comments[lineno] = "#{indent}# @rbs #{comment}\n"
        end

        super
      end

      private

      # @rbs (Symbol) -> AST::Members::MethodDefinition?
      def find_method_definition(name)
        return if @context.empty?

        type_name = TypeName.parse("::#{@context.join("::")}")
        decl = @decls[type_name]
        return unless decl

        decl.members.find do |member|
          member.is_a?(AST::Members::MethodDefinition) && member.name == name
        end
      end

      # @rbs (Prism::ModuleNode | Prism::ClassNode) { () -> void } -> void
      def with_context(node)
        constant_path = node.constant_path

        case constant_path
        when Prism::ConstantReadNode, Prism::ConstantPathNode
          names = constant_path.full_name_parts
          @context.push(*names)

          yield

          @context.pop(names.size)
        else
          yield
        end
      end
    end
  end
end
