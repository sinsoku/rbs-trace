# frozen_string_literal: true

RSpec.describe RBS::Trace::OverloadCompact do
  describe "#call" do
    def merge(*sources)
      overloads = sources.map do |source|
        method_type = RBS::Parser.parse_method_type(source)
        RBS::AST::Members::MethodDefinition::Overload.new(method_type:, annotations: [])
      end
      merged = described_class.new(overloads).call
      merged.map(&:method_type).join(" | ")
    end

    context "when the argument types are different" do
      subject(:rbs) { merge("(String) -> void", "(Integer) -> void") }

      it "merges the argument types" do
        expect(rbs).to eq("(String | Integer) -> void")
      end
    end

    context "when the argument types are String and nil" do
      subject(:rbs) { merge("(String) -> void", "(nil) -> void") }

      it "merges the argument types" do
        expect(rbs).to eq("(String?) -> void")
      end
    end

    context "when the return types are void and bool" do
      subject(:rbs) { merge("() -> void", "() -> bool") }

      it "returns the bool type" do
        expect(rbs).to eq("() -> bool")
      end
    end

    context "when the return types are untyped and bool" do
      subject(:rbs) { merge("() -> untyped", "() -> bool") }

      it "returns the bool type" do
        expect(rbs).to eq("() -> bool")
      end
    end

    context "when the return types are nil and void" do
      subject(:rbs) { merge("() -> nil", "() -> void") }

      it "returns the bool type" do
        expect(rbs).to eq("() -> nil")
      end
    end
  end
end
