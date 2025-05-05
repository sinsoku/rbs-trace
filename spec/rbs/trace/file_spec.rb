# frozen_string_literal: true

require "stringio"

RSpec.describe RBS::Trace::File do
  let(:trace) { RBS::Trace.new(log_level: :debug, raises: true) }

  describe "#with_rbs" do
    it "inserts a comment" do
      source = <<~RUBY
        class A
          def m
          end
        end
      RUBY
      load_source(source) do |mod|
        trace.enable { mod::A.new.m }
        file = trace.files.values.first

        expect(file.with_rbs).to eq(<<~RUBY)
          class A
            # @rbs () -> nil
            def m
            end
          end
        RUBY
      end
    end

    it "supports rbs_keyword comment format" do
      source = <<~RUBY
        class A
          def m
          end
        end
      RUBY
      load_source(source) do |mod|
        trace.enable { mod::A.new.m }
        file = trace.files.values.first

        expect(file.with_rbs(:rbs_keyword)).to eq(<<~RUBY)
          class A
            # @rbs () -> nil
            def m
            end
          end
        RUBY
      end
    end

    it "supports rbs_colon comment format" do
      source = <<~RUBY
        class A
          def m
          end
        end
      RUBY
      load_source(source) do |mod|
        trace.enable { mod::A.new.m }
        file = trace.files.values.first

        expect(file.with_rbs(:rbs_colon)).to eq(<<~RUBY)
          class A
            #: () -> nil
            def m
            end
          end
        RUBY
      end
    end

    it "does not insert a comment if there is a `@rbs` comment" do
      source = <<~RUBY
        class A
          # @rbs (Integer) -> nil
          def m(x)
          end
        end
      RUBY
      load_source(source) do |mod|
        trace.enable { mod::A.new.m("a") }
        file = trace.files.values.first

        expect(file.with_rbs).to eq(<<~RUBY)
          class A
            # @rbs (Integer) -> nil
            def m(x)
            end
          end
        RUBY
      end
    end

    it "does not insert a comment if there is a `#:` comment" do
      source = <<~RUBY
        class A
          #: (Integer) -> void
          def m(x)
          end
        end
      RUBY
      load_source(source) do |mod|
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
    end

    it "does not insert a comment if there is an inline comment using `#:`" do
      source = <<~RUBY
        class A
          def m #: void
          end
        end
      RUBY
      load_source(source) do |mod|
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
  end

  describe "#to_rbs" do
    it "returns RBS string" do
      source = <<~RUBY
        class A
          def m
          end
        end
      RUBY
      load_source(source) do |mod|
        trace.enable { mod::A.new.m }
        file = trace.files.values.first

        expect(file.to_rbs).to eq(<<~RBS)
          class A
            def m: () -> nil
          end
        RBS
      end
    end
  end

  describe "#save_rbs" do
    context "when path is absolute" do
      it "saves RBS files" do
        source = <<~RUBY
          class A
            def m
            end
          end
        RUBY
        load_source(source) do |mod|
          trace.enable { mod::A.new.m }
          file = trace.files.values.first

          Dir.mktmpdir do |out_dir|
            file.save_rbs(out_dir)

            rbs_files = Dir.glob("#{out_dir}/**/*.rbs")
            expect(File.read(rbs_files[0])).to eq(<<~RBS)
              class A
                def m: () -> nil
              end
            RBS
          end
        end
      end
    end

    it "when path is relative" do
      mod = Module.new
      path = Pathname("#{Dir.pwd}/lib/app.rb")
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
            def m: () -> nil
          end
        RBS
      end
    ensure
      path.delete
    end
  end
end
