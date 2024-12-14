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
        builder = Builder.new
        method_type = builder.parse_parameters(@parameters)
        unless void
          type = builder.parse_classes(return_type)
          new_type = method_type.type.with_return_type(type)
          method_type = method_type.update(type: new_type) # rubocop:disable Style/RedundantSelfAssignment
        end

        # Trim spaces for backward compatibility
        "(#{method_type.type.param_to_s}) -> #{method_type.type.return_type}".gsub(" | ", "|")
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
    end
  end
end
