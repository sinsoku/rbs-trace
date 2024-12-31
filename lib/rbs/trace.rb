# frozen_string_literal: true

require "bundler"
require "logger"
require "prism"
require "rbs"

require_relative "trace/helpers"
require_relative "trace/builder"
require_relative "trace/file"
require_relative "trace/inline_comment_visitor"
require_relative "trace/method_tracing"
require_relative "trace/overload_compact"
require_relative "trace/version"

module RBS
  module Trace
    class Error < StandardError; end
  end
end
