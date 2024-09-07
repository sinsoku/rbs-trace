# frozen_string_literal: true

require "bundler"
require "logger"
require "prism"

require_relative "trace/declaration"
require_relative "trace/definition"
require_relative "trace/file"
require_relative "trace/method_tracing"
require_relative "trace/version"

module RBS
  module Trace
    class Error < StandardError; end
  end
end
