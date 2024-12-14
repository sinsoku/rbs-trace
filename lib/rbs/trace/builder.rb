# frozen_string_literal: true

module RBS
  module Trace
    class Builder
      GENERICS_SIZE = {
        Array => 1,
        Range => 1,
        Hash => 2
      }.freeze
      private_constant :GENERICS_SIZE

      # @rbs (Array[untyped]) -> Types::t
      def parse_classes(classes)
        types = classes.filter_map { |klass| parse_class(klass) unless klass == NilClass }.uniq
        return type_nil if types.empty?

        type = types.one? ? types.first : Types::Union.new(types:, location: nil) #: Types::t
        if classes.include?(NilClass)
          Types::Optional.new(type:, location: nil)
        else
          type
        end
      end

      # @rbs (untyped) -> Types::t
      def parse_class(klass)
        if [TrueClass, FalseClass].include?(klass)
          type_bool
        elsif klass == Object
          type_untyped
        else
          size = GENERICS_SIZE[klass].to_i
          args = Array.new(size) { type_untyped }
          Types::ClassInstance.new(name: TypeName(klass.name), args:, location: nil)
        end
      end

      # @rbs (Array[untyped]) -> MethodType
      def parse_parameters(parameters) # rubocop:disable Metrics
        fn = Types::Function.empty(type_void)

        parameters.each do |kind, name, classes|
          fn_params = Types::Function::Param.new(name: nil, type: parse_classes(classes))

          case kind
          when :req
            fn.required_positionals << fn_params
          when :opt
            fn.optional_positionals << fn_params
          when :rest
            fn = fn.update(rest_positionals: fn_params) # rubocop:disable Style/RedundantSelfAssignment
          when :keyreq
            fn.required_keywords[name] = fn_params
          when :key
            fn.optional_keywords[name] = fn_params
          when :keyrest
            fn = fn.update(rest_keywords: fn_params) # rubocop:disable Style/RedundantSelfAssignment
          end
        end

        # TODO: support block argument
        MethodType.new(
          type_params: [],
          type: fn,
          block: nil,
          location: nil
        )
      end

      # @rbs () -> Types::Bases::Void
      def type_void
        @type_void = Types::Bases::Void.new(location: nil)
      end

      # @rbs () -> Types::Bases::Nil
      def type_nil
        @type_nil ||= Types::Bases::Nil.new(location: nil)
      end

      # @rbs () -> Types::Bases::Bool
      def type_bool
        @type_bool ||= Types::Bases::Bool.new(location: nil)
      end

      # @rbs () -> Types::Bases::Any
      def type_untyped
        @type_untyped ||= Types::Bases::Any.new(location: nil)
      end
    end
  end
end
