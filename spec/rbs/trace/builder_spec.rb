# frozen_string_literal: true

RSpec.describe RBS::Trace::Builder do
  describe "#method_call" do
    let(:builder) { described_class.new }

    context "when an instance of a class that overrides the name method" do
      let(:mod) { Module.new }
      let(:klass) do
        Class.new do
          def self.name
            "Bar"
          end
        end
      end

      before { mod.const_set(:Foo, klass) }

      it "returns the type before it was overwritten" do
        foo = mod::Foo.new
        method_type, = builder.method_call(
          bind: binding,
          parameters: [%i[req foo]],
          void: true
        )

        expect(method_type.to_s).to eq("(#{mod}::Foo) -> void")
      end
    end
  end
end
