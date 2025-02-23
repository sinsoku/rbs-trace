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

    context "when `--sig-dir` is not specified" do
      it "embeds RBS into Ruby code" do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            base = Pathname.pwd
            rb_dir = base.join("app").tap(&:mkdir)
            sig_dir = base.join("sig").tap(&:mkdir)

            rb_dir.join("a.rb").write(<<~RUBY)
              class A
                def foo
                  puts "foo"
                end
              end
            RUBY
            sig_dir.join("a.rbs").write(<<~RBS)
              class A
                def foo: () -> void
              end
            RBS

            cli.run(["inline", "--rb-dir", "app"])

            expect(rb_dir.join("a.rb").read).to eq(<<~RUBY)
              class A
                # @rbs () -> void
                def foo
                  puts "foo"
                end
              end
            RUBY
          end
        end
      end
    end

    context "when multiple `--rb-dir` are specified" do
      it "embeds RBS into Ruby code" do
        Dir.mktmpdir do |dir|
          base = Pathname(dir)
          rb_app_dir = base.join("app").tap(&:mkdir)
          rb_lib_dir = base.join("lib").tap(&:mkdir)
          sig_dir = base.join("sig").tap(&:mkdir)

          rb_app_dir.join("a.rb").write(<<~RUBY)
            class A
              def foo
                puts "foo"
              end
            end
          RUBY
          rb_lib_dir.join("b.rb").write(<<~RUBY)
            class B
              def bar
                puts "bar"
              end
            end
          RUBY
          sig_dir.join("x.rbs").write(<<~RBS)
            class A
              def foo: () -> void
            end
            class B
              def bar: () -> void
            end
          RBS

          cli.run(["inline", "--sig-dir", "#{dir}/sig", "--rb-dir", "#{dir}/app", "--rb-dir", "#{dir}/lib"])

          expect(rb_app_dir.join("a.rb").read).to eq(<<~RUBY)
            class A
              # @rbs () -> void
              def foo
                puts "foo"
              end
            end
          RUBY
          expect(rb_lib_dir.join("b.rb").read).to eq(<<~RUBY)
            class B
              # @rbs () -> void
              def bar
                puts "bar"
              end
            end
          RUBY
        end
      end
    end
  end
end
