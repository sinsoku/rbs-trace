# frozen_string_literal: true

module RBS
  module Trace
    class Declaration
      METHOD_KINDS = %i[req opt rest keyreq key keyrest].freeze #: Array[Symbol]
      private_constant :METHOD_KINDS

      attr_reader :parameters #: Array[untyped]
      attr_reader :void #: bool
      attr_accessor :return_type #: Array[Object]

      # @rbs (Array[untyped], ?void: bool) -> void
      def initialize(parameters, void: false)
        @parameters = parameters
        @void = void
      end

      # @rbs () -> String
      def to_rbs
        return_rbs = void ? "void" : convert_type(return_type)

        "(#{parameters_rbs}) -> #{return_rbs}"
      end

      # @rbs (Declaration) -> Declaration
      def merge(other) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        new_parameters = @parameters.map.with_index do |parameter, index|
          kind = parameter[0]
          name = parameter[1]
          klass = parameter[2]
          other_klass = other.parameters[index][2]

          merged_klass = (klass + other_klass).uniq
          [kind, name, merged_klass]
        end
        Declaration.new(new_parameters, void: void && other.void).tap do |decl|
          decl.return_type = (return_type + other.return_type).uniq
        end
      end

      private

      # TODO: support block argument
      # @rbs () -> String
      def parameters_rbs
        converted = {}
        @parameters.each do |kind, name, klass|
          converted[kind] ||= []
          converted[kind] << convert(kind, name, klass)
        end

        METHOD_KINDS.flat_map { |kind| converted[kind] }.compact.join(", ")
      end

      # @rbs (Symbol, Symbol, Array[Object]) -> String?
      def convert(kind, name, klass) # rubocop:disable Metrics/MethodLength
        type = convert_type(klass)
        case kind
        when :req
          type
        when :opt
          "?#{type}"
        when :rest
          "*#{type}"
        when :keyreq
          "#{name}: #{type}"
        when :key
          "?#{name}: #{type}"
        when :keyrest
          "**#{type}"
        end
      end

      # @rbs (Array[Object]) -> String
      def convert_type(klass) # rubocop:disable Metrics
        optional = klass.any? { |k| k == NilClass }
        types = klass.filter_map do |k|
          if k == NilClass
            nil
          elsif [TrueClass, FalseClass].include?(k) # steep:ignore ArgumentTypeMismatch
            "bool"
          elsif k == Object
            "untyped"
          else
            k.name # steep:ignore NoMethod
          end
        end.uniq
        type = types.join("|")

        if types.size > 1 && optional
          "(#{type})?"
        elsif types.empty?
          "nil"
        elsif optional
          "#{type}?"
        else
          type
        end
      end
    end
  end
end
