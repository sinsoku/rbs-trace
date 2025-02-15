# frozen_string_literal: true

RSpec.describe RBS::Trace::CLI do
  describe "#run" do
    let(:cli) { described_class.new }

    context "when no command specified" do
      it "outputs usage" do
        expect { cli.run([]) }.to output(/^Usage: rbs-trace <command>/).to_stdout
      end
    end

    context "when `inline` specified" do
      it "outputs `rbs-trace inline` usage" do
        expect { cli.run(["inline"]) }.to output(/^Usage: rbs-trace inline/).to_stdout
      end
    end

    context "when `merge` specified" do
      it "outputs `rbs-trace merge` usage" do
        expect { cli.run(["merge"]) }.to output(/^Usage: rbs-trace merge/).to_stdout
      end
    end
  end
end
