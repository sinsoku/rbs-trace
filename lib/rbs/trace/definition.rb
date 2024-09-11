# frozen_string_literal: true

module RBS
  module Trace
    class Definition
      attr_reader :klass #: Class
      attr_reader :name #: Symbol
      attr_reader :lineno #: Integer

      # @rbs (klass: Object, name: Symbol, lineno: Integer) -> void
      def initialize(klass:, name:, lineno:)
        @klass = klass
        @name = name
        @lineno = lineno
      end

      # @rbs () -> Array[Declaration]
      def decls
        @decls ||= []
      end

      # @rbs (?Integer) -> String
      def rbs_comment(indent = 0)
        "#{" " * indent}# @rbs #{rbs}\n"
      end

      # @rbs () -> String
      def rbs
        @decls.inject { |result, decl| result.merge(decl) }.to_rbs
      end
    end
  end
end
