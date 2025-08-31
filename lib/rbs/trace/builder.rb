# frozen_string_literal: true

module RBS
  class Trace
    class Builder # rubocop:disable Metrics/ClassLength
      include Helpers

      UNBOUND_CLASS_METHOD = Object.instance_method(:class)
      UNBOUND_NAME_METHOD = Class.instance_method(:name)
      private_constant :UNBOUND_CLASS_METHOD, :UNBOUND_NAME_METHOD

      DEFAULT_GENERICS_SIZE = {
        "Array" => 1,
        "Range" => 1,
        "Hash" => 2
      }.freeze
      private_constant :DEFAULT_GENERICS_SIZE

      # @rbs (bind: Binding, parameters: Array[__todo__], void: bool) -> Array[__todo__]
      def method_call(bind:, parameters:, void:)
        method_type = parse_parameters(bind, parameters)
        return_type = type_void if void

        [method_type, return_type].tap do |types|
          stack_traces << types
        end
      end

      # @rbs (__todo__) -> AST::Members::MethodDefinition::Overload
      def method_return(return_value)
        method_type, return_type = stack_traces.pop

        type = return_type || parse_object(return_value)
        new_type = method_type.type.with_return_type(type)
        method_type = method_type.update(type: new_type) # rubocop:disable Style/RedundantSelfAssignment

        AST::Members::MethodDefinition::Overload.new(method_type:, annotations: [])
      end

      # @rbs () -> Hash[String, Integer]
      def generics_size
        @generics_size ||= DEFAULT_GENERICS_SIZE.dup
      end

      private

      def stack_traces
        @stack_traces ||= {} #: Hash[Thread, Array[__todo__]]
        @stack_traces[Thread.current] ||= [] # steep:ignore UnannotatedEmptyCollection
      end

      # @rbs (Binding, Array[__todo__]) -> MethodType
      def parse_parameters(bind, parameters) # rubocop:disable Metrics
        fn = Types::Function.empty(type_void)

        parameters.each do |kind, name| # rubocop:disable Metrics/BlockLength
          case kind
          when :req
            value = bind.local_variable_get(name)
            fn.required_positionals << Types::Function::Param.new(name: nil, type: parse_object(value))
          when :opt
            value = bind.local_variable_get(name)
            fn.optional_positionals << Types::Function::Param.new(name: nil, type: parse_object(value))
          when :rest
            type = if name.nil? || name == :*
                     type_untyped
                   else
                     value = bind.local_variable_get(name)
                     parse_classes(value.map { |v| obj_to_class(v) }.uniq)
                   end
            fn = fn.update(rest_positionals: Types::Function::Param.new(name: nil, type:)) # rubocop:disable Style/RedundantSelfAssignment
          when :keyreq
            value = bind.local_variable_get(name)
            fn.required_keywords[name] = Types::Function::Param.new(name: nil, type: parse_object(value))
          when :key
            value = bind.local_variable_get(name)
            fn.optional_keywords[name] = Types::Function::Param.new(name: nil, type: parse_object(value))
          when :keyrest
            type = if name.nil? || name == :**
                     type_untyped
                   else
                     value = bind.local_variable_get(name)
                     parse_classes(value.values.map { |v| obj_to_class(v) }.uniq)
                   end
            fn = fn.update(rest_keywords: Types::Function::Param.new(name: nil, type:)) # rubocop:disable Style/RedundantSelfAssignment
          when :block
            # TODO: support block argument
            next
          end
        end

        MethodType.new(
          type_params: [],
          type: fn,
          block: nil,
          location: nil
        )
      end

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
      def parse_class(klass) # rubocop:disable Metrics/MethodLength
        class_name = UNBOUND_NAME_METHOD.bind_call(klass)
        if [TrueClass, FalseClass].include?(klass)
          type_bool
        elsif klass == NilClass
          type_nil
        elsif klass == Object || class_name.nil?
          type_untyped
        else
          size = generics_size[klass.name].to_i
          args = Array.new(size) { type_untyped }
          Types::ClassInstance.new(name: TypeName.parse(class_name), args:, location: nil)
        end
      end

      # @rbs (BasicObject) -> Types::t
      def parse_object(object)
        klass = obj_to_class(object)
        parse_class(klass)
      end

      # @rbs (BasicObject) -> Class
      def obj_to_class(obj)
        UNBOUND_CLASS_METHOD.bind_call(obj)
      end
    end
  end
end
