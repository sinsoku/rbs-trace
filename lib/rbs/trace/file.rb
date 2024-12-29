# frozen_string_literal: true

module RBS
  module Trace
    class File
      # @rbs (String, Environment) -> void
      def initialize(path, env)
        @path = path
        @env = env
      end

      # @rbs (klass: Class, name: Symbol) -> AST::Members::MethodDefinition
      def find_or_new_method_def_decl(klass:, name:)
        receiver_decl = find_or_new_receiver_decl(klass)

        kind = klass.singleton_class? ? :singleton : :instance
        decl = receiver_decl.members.find do |member|
          member.is_a?(AST::Members::MethodDefinition) &&
            member.kind == kind &&
            member.name == name
        end
        return decl if decl

        decl = build_method_decl(name, kind)
        # TODO: Check for problems with mutable operations
        receiver_decl.members << decl
        decl
      end

      # @rbs () -> String
      def with_rbs
        result = Prism.parse_file(@path)
        comments = {} # Hash[Integer, String]
        result.value.accept(InlineCommentVisitor.new(@env, comments))

        lines = result.source.source.lines
        comments.keys.sort.reverse_each do |i|
          next if skip_insert?(lines, i)

          lines.insert(i, comments[i])
        end
        lines.join
      end

      # @rbs () -> void
      def rewrite
        ::File.write(@path, with_rbs)
      end

      private

      # @rbs (Array[String], Integer) -> boolish
      def skip_insert?(lines, current)
        prev = current - 1

        lines[prev]&.include?("# @rbs") ||
        lines[prev]&.include?("#:") ||
        lines[current]&.include?("#:")
      end

      # @rbs (Class | Module) -> AST::Declarations::Class | AST::Declarations::Module
      def find_or_new_receiver_decl(klass)
        # Remove anonymous class names
        class_name = klass.name.split("::").grep_v(/^#/).join("::")
        name = TypeName("::#{class_name}")

        entry = @env.module_class_entry(name)
        return entry.primary.decl if entry

        decl = build_module_class_decl(name, klass)
        @env << decl

        decl
      end

      # @rbs (TypeName, Class | Module) -> AST::Declarations::Class | AST::Declarations::Module
      def build_module_class_decl(name, klass)
        if klass.is_a?(Class)
          AST::Declarations::Class.new(
            name:,
            type_params: [],
            super_class: nil,
            members: [],
            annotations: [],
            location: nil,
            comment: nil
          )
        else
          AST::Declarations::Module.new(
            name:,
            type_params: [],
            self_types: [],
            members: [],
            annotations: [],
            location: nil,
            comment: nil
          )
        end
      end

      # @rbs (Symbol, :singleton | :instance) -> AST::Members::MethodDefinition
      def build_method_decl(name, kind)
        AST::Members::MethodDefinition.new(
          name:,
          kind:,
          overloads: [],
          annotations: [],
          location: nil,
          comment: nil,
          overloading: false,
          visibility: nil
        )
      end
    end
  end
end
