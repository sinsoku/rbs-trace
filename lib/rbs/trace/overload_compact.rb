# frozen_string_literal: true

module RBS
  class Trace
    class OverloadCompact
      # @rbs (Array[AST::Members::MethodDefinition::Overload]) -> void
      def initialize(overloads)
        @overloads = overloads
      end

      # @rbs () -> Array[AST::Members::MethodDefinition::Overload]
      def call
        method_type = merge_method_types(@overloads.map(&:method_type))
        [AST::Members::MethodDefinition::Overload.new(method_type:, annotations: [])]
      end

      private

      # @rbs (Array[MethodType]) -> MethodType
      def merge_method_types(method_types) # rubocop:disable Metrics
        # steep:ignore:start
        base = method_types.first
        return base if method_types.one?

        required_positionals = base.type.required_positionals.map.with_index do |_, i|
          types = method_types.map { |method_type| method_type.type.required_positionals[i].type }.uniq
          Types::Function::Param.new(name: nil, type: merge_types(types))
        end

        optional_positionals = base.type.optional_positionals.map.with_index do |_, i|
          types = method_types.map { |method_type| method_type.type.optional_positionals[i].type }.uniq
          Types::Function::Param.new(name: nil, type: merge_types(types))
        end

        types = method_types.filter_map { |method_type| method_type.type.rest_positionals }.uniq
        rest_positionals = Types::Function::Param.new(name: nil, type: merge_types(types)) unless types.empty?

        required_keywords = base.type.required_keywords.keys.to_h do |key|
          types = method_types.map { |method_type| method_type.type.required_keywords[key] }.uniq
          [key, Types::Function::Param.new(name: nil, type: merge_types(types))]
        end

        optional_keywords = base.type.optional_keywords.keys.to_h do |key|
          types = method_types.map { |method_type| method_type.type.optional_keywords[key] }.uniq
          [key, Types::Function::Param.new(name: nil, type: merge_types(types))]
        end

        types = method_types.filter_map { |method_type| method_type.type.rest_keywords }.uniq
        rest_keywords = Types::Function::Param.new(name: nil, type: merge_types(types)) unless types.empty?

        return_types = method_types.map { |method_type| method_type.type.return_type }.uniq
        return_type = merge_types(return_types)
        # steep:ignore:end

        fn = Types::Function.new(
          required_positionals:,
          optional_positionals:,
          rest_positionals:,
          trailing_positionals: [],
          required_keywords:,
          optional_keywords:,
          rest_keywords:,
          return_type:
        )
        MethodType.new(
          type_params: [],
          type: fn,
          block: nil,
          location: nil
        )
      end

      # @rbs (Array[Types::t]) -> Types::t
      def merge_types(types)
        types = compact_types(types)
        return types.first if types.one?

        optional = types.any?(Types::Bases::Nil)
        types = types.reject { |type| type.is_a?(Types::Bases::Nil) }
        type = types.one? ? types.first : Types::Union.new(types:, location: nil) #: Types::t

        optional ? Types::Optional.new(type:, location: nil) : type
      end

      # @rbs (Array[Types::t]) -> Array[Types::t]
      def compact_types(types)
        types = types.reject { |t| t.is_a?(Types::Bases::Void) } if types.any? { |t| !t.is_a?(Types::Bases::Void) }
        types.reject! { |t| t.is_a?(Types::Bases::Any) } if types.any? { |t| !t.is_a?(Types::Bases::Any) }
        types
      end
    end
  end
end
