# frozen_string_literal: true

RSpec.describe RBS::Trace::CLI::Inline do
  describe "#run" do
    let(:cli) { described_class.new }

    it "embeds RBS into Ruby code" do
      Dir.mktmpdir do |dir|
        base = Pathname(dir)
        rb_dir = base.join("app").tap(&:mkdir)
        sig_dir = base.join("sig").tap(&:mkdir)

        rb_dir.join("a.rb").write(<<~RUBY)
          class A
            def say
              puts "hello"
            end

            def sum(x, y)
              x + y
            end
          end
        RUBY
        sig_dir.join("a.rbs").write(<<~RBS)
          class A
            def say: () -> void

            def sum: (Integer x, Integer y) -> Integer
          end
        RBS

        cli.run(["inline", "--sig-dir", "#{dir}/sig", "--rb-dir", "#{dir}/app"])

        expect(rb_dir.join("a.rb").read).to eq(<<~RUBY)
          class A
            # @rbs () -> void
            def say
              puts "hello"
            end

            # @rbs (Integer x, Integer y) -> Integer
            def sum(x, y)
              x + y
            end
          end
        RUBY
      end
    end
  end
end
