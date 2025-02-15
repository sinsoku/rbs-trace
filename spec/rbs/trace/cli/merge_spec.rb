# frozen_string_literal: true

RSpec.describe RBS::Trace::CLI::Merge do
  describe "#run" do
    let(:cli) { described_class.new }

    it "merges RBS files into one" do
      Dir.mktmpdir do |dir|
        base = Pathname(dir)
        sig_dir = base.join("sig").tap(&:mkdir)

        sig_dir.join("a.rbs").write(<<~RBS)
          class A
            def m: () -> void
          end
        RBS
        sig_dir.join("b.rbs").write(<<~RBS)
          class B
            def m: () -> void
          end
        RBS

        expect do
          cli.run(["merge", "--sig-dir", "#{dir}/sig"])
        end.to output(<<~RBS).to_stdout
          class A
            def m: () -> void
          end
          class B
            def m: () -> void
          end
        RBS
      end
    end
  end
end
