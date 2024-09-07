# frozen_string_literal: true

require "stringio"

RSpec.describe RBS::Trace::File do
  let(:mod) { Module.new }

  it "inserts a comment" do
    source = <<~RUBY
      class A
        def m
        end
      end
    RUBY
    file = trace_source(source, mod) { mod::A.new.m }
    expect(file.with_rbs).to eq(<<~RUBY)
      class A
        # @rbs () -> void
        def m
        end
      end
    RUBY
  end

  it "does not overwrite a comment for rbs-inline" do
    source = <<~RUBY
      class A
        # @rbs (Integer) -> void
        def m(x)
        end
      end
    RUBY
    file = trace_source(source, mod) { mod::A.new.m("a") }
    expect(file.with_rbs).to eq(<<~RUBY)
      class A
        # @rbs (Integer) -> void
        def m(x)
        end
      end
    RUBY
  end
end
