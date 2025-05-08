# frozen_string_literal: true

require "stringio"

module RBS
  class Trace
    class File
      include Helpers

      # @rbs (String, ?Hash[TypeName, AST::Declarations::t]) -> void
      def initialize(path, decls = {})
        @path = path
        @decls = decls
        @members = {} #: Hash[TypeName, AST::Declarations::t]
      end

      # @rbs (untyped, Class, Symbol) -> AST::Members::MethodDefinition?
      def find_or_new_method_definition(object, defined_class, name)
        klass = defined_class.singleton_class? ? object : defined_class
        receiver_decl = find_or_new_receiver_decl(klass)
        return unless receiver_decl

        kind = defined_class.singleton_class? ? :singleton : :instance
        key = [receiver_decl.name, name, kind]
        @members[key] ||= new_method_definition(name:, kind:).tap do |member| # steep:ignore ArgumentTypeMismatch
          receiver_decl.members << member
        end
      end

      # @rbs (?Symbol?) -> String
      def with_rbs(comment_format = nil)
        result = Prism.parse_file(@path)
        comments = {} #: Hash[Integer, String]
        result.value.accept(InlineCommentVisitor.new(@decls, comments, comment_format))

        lines = result.source.source.lines
        comments.keys.sort.reverse_each do |i|
          next if skip_insert?(lines, i)

          lines.insert(i, comments[i])
        end
        lines.join
      end

      # @rbs (?Symbol?) -> void
      def rewrite(comment_format = nil)
        ::File.write(@path, with_rbs(comment_format))
      end

      # @rbs () -> String
      def to_rbs
        out = StringIO.new
        writer = Writer.new(out:)
        writer.write(@decls.values)

        out.string
      end

      # @rbs (String) -> void
      def save_rbs(out_dir)
        rbs_path = calc_rbs_path(out_dir)

        rbs_path.parent.mkpath unless rbs_path.parent.exist?
        rbs_path.write(to_rbs)
      end

      private

      # @rbs (Array[String], Integer) -> boolish
      def skip_insert?(lines, current)
        prev = current - 1

        lines[prev]&.include?("# @rbs") ||
          lines[prev]&.include?("#:") ||
          lines[current]&.include?("#:")
      end

      # @rbs (Class | Module) -> (AST::Declarations::Class | AST::Declarations::Module)?
      def find_or_new_receiver_decl(klass)
        return unless klass.name
        return if klass.name.is_a?(Symbol)

        # Remove anonymous class names
        class_name = klass.name.to_s.split("::").grep_v(/^#/).join("::")
        name = TypeName.parse(class_name)

        @decls[name.absolute!] ||= klass.is_a?(Class) ? new_class_decl(name:) : new_module_decl(name:)
      end

      # @rbs (String) -> Pathname
      def calc_rbs_path(out_dir)
        rb_path = Pathname(@path).sub(Pathname.pwd.to_s, "")
        rb_path = rb_path.relative_path_from("/") if rb_path.absolute?
        rbs_path = rb_path.sub_ext(".rbs")

        Pathname(out_dir) + rbs_path
      end
    end
  end
end
