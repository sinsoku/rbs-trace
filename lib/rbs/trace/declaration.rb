# frozen_string_literal: true

module RBS
  module Trace
    class Declaration
      METHOD_KINDS = %i[req opt rest keyreq key keyrest].freeze
      private_constant :METHOD_KINDS

      attr_accessor :return_type

      def initialize(parameters, void: false)
        @parameters = parameters
        @void = void
      end

      def to_rbs
        ret = if @void
                "void"
              elsif @return_type == NilClass
                "nil"
              elsif @return_type == TrueClass || @return_type == FalseClass
                "bool"
              else
                @return_type
              end

        "(#{parameters_rbs}) -> #{ret}"
      end

      private

      # TODO: support block argument
      def parameters_rbs
        converted = {}
        @parameters.each do |kind, name, klass|
          converted[kind] ||= []
          converted[kind] << convert(kind, name, klass)
        end

        METHOD_KINDS.flat_map { |kind| converted[kind] }.compact.join(", ")
      end

      def select_parameters(selected)
        @parameters.select { |kind, _name, _klass| kind == selected }
      end

      def convert(kind, name, klass) # rubocop:disable Metrics/MethodLength
        case kind
        when :req
          klass
        when :opt
          "?#{klass}"
        when :rest
          "*#{klass.join("|")}"
        when :keyreq
          "#{name}: #{klass}"
        when :key
          "?#{name}: #{klass}"
        when :keyrest
          "**#{klass.join("|")}"
        end
      end
    end
  end
end
