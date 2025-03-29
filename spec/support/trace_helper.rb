# frozen_string_literal: true

require "tempfile"

module TraceHelper
  # @rbs (String) { (Module) -> void } -> void
  def load_source(source)
    tf = Tempfile.open(["", ".rb"], "tmp") do |fp|
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
