# frozen_string_literal: true

module RBS
  module Trace
    class Definition
      attr_reader :klass, :name, :lineno

      def initialize(klass:, name:, lineno:)
        @klass = klass
        @name = name
        @lineno = lineno
      end

      def decls
        @decls ||= []
      end

      def rbs_comment(indent = 0)
        "#{" " * indent}# @rbs #{rbs}\n"
      end

      def rbs
        # TODO: merge multiple decls
        @decls.first.to_rbs
      end
    end
  end
end
