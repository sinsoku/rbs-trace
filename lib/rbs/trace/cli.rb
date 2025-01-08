# frozen_string_literal: true

module RBS
  module Trace
    class CLI
      BANNER = <<~USAGE
        Usage: rbs-trace <command> [<args>]

        Available commands: inline, merge
      USAGE

      # @rbs (Array[String]) -> void
      def run(args = ARGV)
        opts = OptionParser.new(BANNER)
        opts.version = RBS::Trace::VERSION
        opts.order!(args)
        command = args.shift&.to_sym

        klass = command_class(command)
        if klass
          klass.new.run(args)
        else
          puts opts.help
        end
      end

      private

      # @rbs (Symbol?) -> (singleton(Inline) | singleton(Merge))?
      def command_class(command)
        case command
        when :inline
          Inline
        when :merge
          Merge
        end
      end
    end
  end
end
