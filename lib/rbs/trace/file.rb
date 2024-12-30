# frozen_string_literal: true

module RBS
  module Trace
    class File
      # @rbs (String, Environment) -> void
      def initialize(path, env)
        @path = path
        @env = env
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
    end
  end
end
