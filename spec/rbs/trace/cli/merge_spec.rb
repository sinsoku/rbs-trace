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

    context "when multiple directories are specified" do
      it "merges RBS files into one" do
        Dir.mktmpdir do |dir|
          base = Pathname(dir)
          sig_1 = base.join("sig_1").tap(&:mkdir)
          sig_1.join("a.rbs").write(<<~RBS)
            class A
              def m: () -> void
            end
          RBS
          sig_2 = base.join("sig_2").tap(&:mkdir)
          sig_2.join("b.rbs").write(<<~RBS)
            class B
              def m: () -> void
            end
          RBS

          expect do
            cli.run(["merge", "--sig-dir", "#{dir}/sig_1", "--sig-dir", "#{dir}/sig_2"])
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

    context "when a class has the another method definition" do
      it "merges RBS files into one" do
        Dir.mktmpdir do |dir|
          base = Pathname(dir)
          sig_dir = base.join("sig").tap(&:mkdir)
          sig_dir.join("a_1.rbs").write(<<~RBS)
            class A
              def x: () -> void
            end
          RBS
          sig_dir.join("a_2.rbs").write(<<~RBS)
            class A
              def y: () -> void
            end
          RBS

          expect do
            cli.run(["merge", "--sig-dir", "#{dir}/sig"])
          end.to output(<<~RBS).to_stdout
            class A
              def x: () -> void
              def y: () -> void
            end
          RBS
        end
      end
    end

    context "when a class has the same method definition" do
      it "merges RBS files into one" do
        Dir.mktmpdir do |dir|
          base = Pathname(dir)
          sig_dir = base.join("sig").tap(&:mkdir)
          sig_dir.join("a_1.rbs").write(<<~RBS)
            class A
              def m: () -> void
            end
          RBS
          sig_dir.join("a_2.rbs").write(<<~RBS)
            class A
              def m: () -> void
            end
          RBS

          expect do
            cli.run(["merge", "--sig-dir", "#{dir}/sig"])
          end.to output(<<~RBS).to_stdout
            class A
              def m: () -> void
            end
          RBS
        end
      end
    end

    context "when a class has the same method name but different types" do
      it "merges RBS files into one" do
        Dir.mktmpdir do |dir|
          base = Pathname(dir)
          sig_dir = base.join("sig").tap(&:mkdir)
          sig_dir.join("a_1.rbs").write(<<~RBS)
            class A
              def m: (Integer) -> void
            end
          RBS
          sig_dir.join("a_2.rbs").write(<<~RBS)
            class A
              def m: (String) -> void
            end
          RBS

          expect do
            cli.run(["merge", "--sig-dir", "#{dir}/sig"])
          end.to output(<<~RBS).to_stdout
            class A
              def m: (Integer) -> void
                   | (String) -> void
            end
          RBS
        end
      end
    end

    context "when a class has a singleton method with the same name" do
      it "does not merge the two methods" do
        Dir.mktmpdir do |dir|
          base = Pathname(dir)
          sig_dir = base.join("sig").tap(&:mkdir)
          sig_dir.join("a_1.rbs").write(<<~RBS)
            class A
              def m: () -> void
            end
          RBS
          sig_dir.join("a_2.rbs").write(<<~RBS)
            class A
              def self.m: (String) -> void
            end
          RBS

          expect do
            cli.run(["merge", "--sig-dir", "#{dir}/sig"])
          end.to output(<<~RBS).to_stdout
            class A
              def m: () -> void
              def self.m: (String) -> void
            end
          RBS
        end
      end
    end
  end
end
