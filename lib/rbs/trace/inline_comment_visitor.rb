# frozen_string_literal: true

module RBS
  module Trace
    class InlineCommentVisitor < Prism::Visitor
      def initialize(env, comments)
        @env = env
        @comments = comments
        @context = []
      end

      def visit_class_node(node)
        @context.push(node.name)
        super
        @context.pop
      end

      def visit_module_node(node)
        @context.push(node.name)
        super
        @context.pop
      end

      def visit_def_node(node)
        name = TypeName("::#{@context.join("::")}")
        entry = @env.module_class_entry(name)

        if entry
          decl = entry.primary.decl
          member = decl.members.find do |member|
            member.is_a?(AST::Members::MethodDefinition) &&
              member.name == node.name
          end

          if member
            index = node.location.start_line - 1
            indent = " " * node.location.start_column
            method_type = member.overloads[0]

            @comments[index] = "#{indent}# @rbs #{method_type}\n"
          end
        end

        super
      end
    end
  end
end
