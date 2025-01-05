# frozen_string_literal: true

module RBS
  module Trace
    module Helpers
      UNBOUND_CLASS_METHOD = Object.instance_method(:class)
      private_constant :UNBOUND_CLASS_METHOD

      # @rbs (name: TypeName) -> AST::Declarations::Module
      def new_module_decl(name:)
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

      # @rbs (name: TypeName) -> AST::Declarations::Class
      def new_class_decl(name:)
        AST::Declarations::Class.new(
          name:,
          type_params: [],
          super_class: nil,
          members: [],
          annotations: [],
          location: nil,
          comment: nil
        )
      end

      # @rbs (name: Symbol, kind: (:singleton | :instance)) -> AST::Members::MethodDefinition
      def new_method_definition(name:, kind:)
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

      # @rbs (BasicObject) -> Class
      def obj_to_class(obj)
        UNBOUND_CLASS_METHOD.bind_call(obj)
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
