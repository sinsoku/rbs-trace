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

  it "supports Union type arguments" do
    source = <<~RUBY
      class A
        def m(x)
        end
      end
    RUBY
    file = trace_source(source, mod) do
      obj = mod::A.new
      obj.m(1)
      obj.m("a")
    end

    definition = file.definitions["#{mod}::A#m"]
    expect(definition.rbs).to eq("(Integer|String) -> void")
  end

  it "supports Union type return value" do
    source = <<~RUBY
      class A
        def m(is_int)
          is_int ? 1 : "a"
        end
      end
    RUBY
    file = trace_source(source, mod) do
      obj = mod::A.new
      result_int = obj.m(true) # rubocop:disable Lint/UselessAssignment
      result_str = obj.m(false) # rubocop:disable Lint/UselessAssignment
    end

    definition = file.definitions["#{mod}::A#m"]
    expect(definition.rbs).to eq("(bool) -> Integer|String")
  end

  it "supports Optional type arguments" do
    source = <<~RUBY
      class A
        def m(x)
        end
      end
    RUBY
    file = trace_source(source, mod) do
      obj = mod::A.new
      obj.m(1)
      obj.m(nil)
    end

    definition = file.definitions["#{mod}::A#m"]
    expect(definition.rbs).to eq("(Integer?) -> void")
  end

  it "if the argument is nil, the RBS argument will also be nil" do
    source = <<~RUBY
      class A
        def m(x)
        end
      end
    RUBY
    file = trace_source(source, mod) { mod::A.new.m(nil) }

    definition = file.definitions["#{mod}::A#m"]
    expect(definition.rbs).to eq("(nil) -> void")
  end

  it "ignores a method generated by class_eval" do
    source = <<~RUBY
      class A
        class_eval('def m; 1; end')
      end
    RUBY
    tf = Tempfile.open do |fp|
      fp.write(source)
      fp
    end
    load(tf.path, mod)

    tracing = described_class.new
    tracing.enable { mod::A.new.m }
    expect(tracing.files).to be_empty
  end

  it "supports anonymous arguments" do
    source = <<~RUBY
      class A
        def m(*, **, &)
        end
      end
    RUBY
    file = trace_source(source, mod) { mod::A.new.m }

    definition = file.definitions["#{mod}::A#m"]
    expect(definition.rbs).to eq("(*untyped, **untyped) -> void")
  end

  it "supports generics with Array and Hash" do
    source = <<~RUBY
      class A
        def m(x, y)
        end
      end
    RUBY
    file = trace_source(source, mod) { mod::A.new.m([], {}) }

    definition = file.definitions["#{mod}::A#m"]
    expect(definition.rbs).to eq("(Array[untyped], Hash[untyped]) -> void")
  end
end
