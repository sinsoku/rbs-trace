# frozen_string_literal: true

module RBS
  module Trace
    class EnvironmentBuilder
      GENERICS_SIZE = {
        Array => 1,
        Range => 1,
        Hash => 2
      }.freeze
      private_constant :GENERICS_SIZE

      attr_reader :env #: Environment

      def initialize
        @env = Environment.new
        @stack_traces = []
      end

      def method_call(object:, name:, bind:, parameters:, void:)
        member = find_or_new_method_definition(object, name)

        method_type = parse_method_parameters(bind, parameters)
        return_type = type_void if void

        @stack_traces << [method_type, return_type]
      end

      def method_return(object:, name:, return_value:)
        method_type, return_type = @stack_traces.pop
        # TODO: check usecase where method_type is nil
        return unless method_type

        member = find_or_new_method_definition(object, name)

        type = return_type || parse_object(return_value)
        new_type = method_type.type.with_return_type(type)
        method_type = method_type.update(type: new_type) # rubocop:disable Style/RedundantSelfAssignment
        overload = RBS::AST::Members::MethodDefinition::Overload.new(method_type:, annotations: [])
        return if member.overloads.include?(overload)

        # TODO: Check for problems with mutable operations
        member.overloads << overload
      end

      private

      # @rbs (Object, Symbol) -> AST::Members::MethodDefinition
      def find_or_new_method_definition(object, name)
        is_singleton = obj_to_class(object) == Class
        klass = is_singleton ? object : obj_to_class(object)
        receiver_decl = find_or_new_receiver_decl(klass)

        kind = is_singleton ? :singleton : :instance
        decl = receiver_decl.members.find do |member|
          member.is_a?(AST::Members::MethodDefinition) &&
            member.kind == kind &&
            member.name == name
        end
        return decl if decl

        decl = build_method_decl(name, kind)
        # TODO: Check for problems with mutable operations
        receiver_decl.members << decl
        decl
      end

      # @rbs (Object) -> AST::Declarations::Class | AST::Declarations::Module
      def find_or_new_receiver_decl(klass)
        # Remove anonymous class names
        class_name = klass.name.split("::").grep_v(/^#/).join("::")
        name = TypeName("::#{class_name}")

        entry = env.module_class_entry(name)
        return entry.primary.decl if entry

        decl = build_module_class_decl(name, klass)
        env << decl

        decl
      end

      # @rbs (TypeName, Class | Module) -> AST::Declarations::Class | AST::Declarations::Module
      def build_module_class_decl(name, klass)
        if klass.is_a?(Class)
          AST::Declarations::Class.new(
            name:,
            type_params: [],
            super_class: nil,
            members: [],
            annotations: [],
            location: nil,
            comment: nil
          )
        else
          AST::Declarations::Module.new(
            name:,
            type_params: [],
            self_types: [],
            members: [],
            annotations: [],
            location: nil,
            comment: nil
          )
        end
      end

      # @rbs (Symbol, :singleton | :instance) -> AST::Members::MethodDefinition
      def build_method_decl(name, kind)
        AST::Members::MethodDefinition.new(
          name:,
          kind:,
          overloads: [],
          annotations: [],
          location: nil,
          comment: nil,
          overloading: false,
          visibility: nil
        )
      end

      # @rbs (Binding, Array[untyped]) -> MethodType
      def parse_method_parameters(bind, parameters)
        parameters_with_class = parameters.filter_map do |kind, name|
          # steep:ignore:start
          value = bind.local_variable_get(name) if name && !%i[* ** &].include?(name)
          # steep:ignore:end
          classes = case kind
                  when :rest
                    value ? value.map { |v| obj_to_class(v) }.uniq : [Object]
                  when :keyrest
                    value ? value.map { |_, v| obj_to_class(v) }.uniq : [Object]
                  when :block
                    # TODO: support block argument
                    next
                  else
                    [obj_to_class(value)]
                  end
          [kind, name, classes]
        end

        parse_parameters(parameters_with_class)
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

      # @rbs (BasicObject) -> Types::t
      def parse_object(object)
        klass = obj_to_class(object)
        parse_class(klass)
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

      # @rbs (BasicObject) -> Class
      def obj_to_class(obj)
        Object.instance_method(:class).bind_call(obj)
      end
    end
  end
end
