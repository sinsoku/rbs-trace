# frozen_string_literal: true

module RBS
  module Trace
    class File
      # @rbs (String) -> void
      def initialize(path)
        @path = path
      end

      # @rbs () -> Hash[String, Definition]
      def definitions
        @definitions ||= {}
      end

      # @rbs () -> String
      def with_rbs
        lines = ::File.readlines(@path)
        reverse_definitions.each do |d|
          next if skip_insert?(lines, d)

          current = d.lineno - 1
          indent = lines[current]&.index("def")
          next unless indent

          lines.insert(current, d.rbs_comment(indent))
        end
        lines.join
      end

      # @rbs () -> void
      def rewrite
        ::File.write(@path, with_rbs)
      end

      private

      # @rbs (Array[String], Definition) -> boolish
      def skip_insert?(lines, definition)
        prev = definition.lineno - 2

        definition.decls.empty? || lines[prev]&.include?("# @rbs")
      end

      # @rbs () -> Enumerator[Definition, void]
      def reverse_definitions
        @definitions.values.sort_by { |d| -d.lineno }
      end
    end
  end
end
