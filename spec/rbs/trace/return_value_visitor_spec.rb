# frozen_string_literal: true

require "stringio"

RSpec.describe RBS::Trace::ReturnValueVisitor do
  describe ".parse_file" do
    def parse_file(source)
      puts(source)
      tf = Tempfile.open do |fp|
        fp.write(source)
        fp
      end
      described_class.parse_file(tf.path)
    end

    context "when a normal method call" do
      subject do
        parse_file(<<~RUBY)
          foo
        RUBY
      end

      it { is_expected.to be_void_type(1, :foo) }
    end

    context "when assignment to local variable" do
      subject do
        parse_file(<<~RUBY)
          x = foo
        RUBY
      end

      it { is_expected.not_to be_void_type(1, :foo) }
    end

    context "when assignment to instance variable" do
      subject do
        parse_file(<<~RUBY)
          @x = foo
        RUBY
      end

      it { is_expected.not_to be_void_type(1, :foo) }
    end

    context "when assignment to class variable" do
      subject do
        parse_file(<<~RUBY)
          @@x = foo
        RUBY
      end

      it { is_expected.not_to be_void_type(1, :foo) }
    end

    context "when assignment to constant variable" do
      subject do
        parse_file(<<~RUBY)
          X = foo
        RUBY
      end

      it { is_expected.not_to be_void_type(1, :foo) }
    end

    context "when a string interpolation" do
      subject do
        parse_file(<<~RUBY)
          "\#{foo}"
        RUBY
      end

      it { is_expected.not_to be_void_type(1, :foo) }
    end

    context "when a method chain" do
      subject do
        parse_file(<<~RUBY)
          foo.bar.buz
        RUBY
      end

      it { is_expected.not_to be_void_type(1, :foo) }
      it { is_expected.not_to be_void_type(1, :bar) }
      it { is_expected.to be_void_type(1, :buz) }
    end
  end
end
