# frozen_string_literal: true

require "tempfile"

module TraceHelper
  # @rbs (String) { (Module) -> void } -> void
  def load_source(source)
    tmpdir = File.expand_path("../../tmp", __dir__)
    tf = Tempfile.open(["", ".rb"], tmpdir) do |fp|
      fp.write(source)
      fp
    end
    mod = Module.new
    load(tf.path, mod)

    yield(mod)
  end
end

RSpec.configure do |config|
  config.include TraceHelper
end
