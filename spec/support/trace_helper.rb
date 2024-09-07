# frozen_string_literal: true

require "tempfile"

module TraceHelper
  def trace_source(source, mod, &)
    tf = Tempfile.open do |fp|
      fp.write(source)
      fp
    end
    load(tf.path, mod)

    tracing = RBS::Trace::MethodTracing.new
    tracing.enable(&)
    tracing.files[tf.path]
  end
end

RSpec.configure do |config|
  config.include TraceHelper
end
