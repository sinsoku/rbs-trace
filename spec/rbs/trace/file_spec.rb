# frozen_string_literal: true

require "stringio"

RSpec.describe RBS::Trace::File do
  let(:trace) { RBS::Trace.new(log_level: :debug, raises: true) }

  describe "#with_rbs" do
    it "inserts a comment" do
      mod = load_source(<<~RUBY)
        class A
          def m
          end
        end
      RUBY
      trace.enable { mod::A.new.m }
      file = trace.files.values.first

      expect(file.with_rbs).to eq(<<~RUBY)
        class A
          # @rbs () -> void
          def m
          end
        end
      RUBY
    end

    it "does not insert a comment if there is a `@rbs` comment" do
      mod = load_source(<<~RUBY)
        class A
          # @rbs (Integer) -> void
          def m(x)
          end
        end
      RUBY
      trace.enable { mod::A.new.m("a") }
      file = trace.files.values.first

      expect(file.with_rbs).to eq(<<~RUBY)
        class A
          # @rbs (Integer) -> void
          def m(x)
          end
        end
      RUBY
    end

    it "does not insert a comment if there is a `#:` comment" do
      mod = load_source(<<~RUBY)
        class A
          #: (Integer) -> void
          def m(x)
          end
        end
      RUBY
      trace.enable { mod::A.new.m("a") }
      file = trace.files.values.first

      expect(file.with_rbs).to eq(<<~RUBY)
        class A
          #: (Integer) -> void
          def m(x)
          end
        end
      RUBY
    end

    it "does not insert a comment if there is an inline comment using `#:`" do
      mod = load_source(<<~RUBY)
        class A
          def m #: void
          end
        end
      RUBY
      trace.enable { mod::A.new.m }
      file = trace.files.values.first

      expect(file.with_rbs).to eq(<<~RUBY)
        class A
          def m #: void
          end
        end
      RUBY
    end
  end

  describe "#to_rbs" do
    it "returns RBS string" do
      mod = load_source(<<~RUBY)
        class A
          def m
          end
        end
      RUBY
      trace.enable { mod::A.new.m }
      file = trace.files.values.first

      expect(file.to_rbs).to eq(<<~RBS)
        class A
          def m: () -> void
        end
      RBS
    end
  end

  describe "#save_rbs" do
    context "when path is absolute" do
      it "saves RBS files" do
        mod = load_source(<<~RUBY)
          class A
            def m
            end
          end
        RUBY
        trace.enable { mod::A.new.m }
        file = trace.files.values.first

        Dir.mktmpdir do |out_dir|
          file.save_rbs(out_dir)

          rbs_files = Dir.glob("#{out_dir}/**/*.rbs")
          expect(File.read(rbs_files[0])).to eq(<<~RBS)
            class A
              def m: () -> void
            end
          RBS
        end
      end
    end

    it "when path is relative" do # rubocop:disable RSpec/ExampleLength
      mod = Module.new
      path = Pathname("lib/app.rb")
      path.write(<<~RUBY)
        class A
          def m
          end
        end
      RUBY
      load(path.to_s, mod)

      trace.enable { mod::A.new.m }
      file = trace.files[path.to_s]

      Dir.mktmpdir do |out_dir|
        file.save_rbs(out_dir)

        expect(File.read("#{out_dir}/lib/app.rbs")).to eq(<<~RBS)
          class A
            def m: () -> void
          end
        RBS
      end
    ensure
      path.delete
    end
  end
end
