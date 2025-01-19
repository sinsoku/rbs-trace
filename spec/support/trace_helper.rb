# frozen_string_literal: true

require "tempfile"

module TraceHelper
  def trace_source(source, mod, &)
    tf = Tempfile.open(["", ".rb"]) do |fp|
      fp.write(source)
      fp
    end
    load(tf.path, mod)

    trace = RBS::Trace.new(log_level: :debug, raises: true)
    trace.enable(&)
    trace.files[tf.path]
  end
end

RSpec.configure do |config|
  config.include TraceHelper
end
