# frozen_string_literal: true

RSpec.describe RBS::Trace::MethodTracing do
  let(:mod) { Module.new }

  it "supports instance methods without arguments" do
    source = <<~RUBY
      class A
        def m
        end
      end
    RUBY
    file = trace_source(source, mod) { mod::A.new.m }

    definition = file.definitions["#{mod}::A#m"]
    expect(definition.rbs).to eq("() -> void")
  end

  it "supports instance methods with req arguments" do
    source = <<~RUBY
      class A
        def m(x)
        end
      end
    RUBY
    file = trace_source(source, mod) { mod::A.new.m(1) }

    definition = file.definitions["#{mod}::A#m"]
    expect(definition.rbs).to eq("(Integer) -> void")
  end

  it "supports instance methods with opt arguments" do
    source = <<~RUBY
      class A
        def m(x = 1)
        end
      end
    RUBY
    file = trace_source(source, mod) { mod::A.new.m }

    definition = file.definitions["#{mod}::A#m"]
    expect(definition.rbs).to eq("(?Integer) -> void")
  end

  it "supports instance methods with rest arguments" do
    source = <<~RUBY
      class A
        def m(*x)
        end
      end
    RUBY
    file = trace_source(source, mod) { mod::A.new.m(1, 2) }

    definition = file.definitions["#{mod}::A#m"]
    expect(definition.rbs).to eq("(*Integer) -> void")
  end

  it "supports instance methods with keyreq arguments" do
    source = <<~RUBY
      class A
        def m(x:)
        end
      end
    RUBY
    file = trace_source(source, mod) { mod::A.new.m(x: 1) }

    definition = file.definitions["#{mod}::A#m"]
    expect(definition.rbs).to eq("(x: Integer) -> void")
  end

  it "supports instance methods with key arguments" do
    source = <<~RUBY
      class A
        def m(x: 0)
        end
      end
    RUBY
    file = trace_source(source, mod) { mod::A.new.m }

    definition = file.definitions["#{mod}::A#m"]
    expect(definition.rbs).to eq("(?x: Integer) -> void")
  end

  it "supports instance methods with keyrest arguments" do
    source = <<~RUBY
      class A
        def m(**opts)
        end
      end
    RUBY
    file = trace_source(source, mod) { mod::A.new.m(x: 1, y: 2) }

    definition = file.definitions["#{mod}::A#m"]
    expect(definition.rbs).to eq("(**Integer) -> void")
  end

  it "supports instance methods with raise" do
    source = <<~RUBY
      class A
        def m
          raise "error"
        end
      end
    RUBY
    file = trace_source(source, mod) do
      mod::A.new.m
    rescue StandardError
      nil
    end

    definition = file.definitions["#{mod}::A#m"]
    expect(definition.rbs).to eq("() -> void")
  end

  it "supports singleton methods" do
    source = <<~RUBY
      class A
        def self.m
        end
      end
    RUBY
    file = trace_source(source, mod) { mod::A.m }

    definition = file.definitions["#{mod}::A.m"]
    expect(definition.rbs).to eq("() -> void")
  end
end
