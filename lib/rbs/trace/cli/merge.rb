# frozen_string_literal: true

module RBS
  class Trace
    class CLI
      class Merge
        BANNER = <<~USAGE
          Usage: rbs-trace merge --sig-dir=DIR

          Merge multiple RBS files into one.

          Examples:
            # Merge RBS files in `tmp/sig-1/` and `tmp/sig-2/`.
            $ rbs-trace merge --sig-dir=tmp/sig-1 --sig-dir=tmp/sig-2

          Options:
        USAGE

        # @rbs (Array[String]) -> void
        def run(args) # rubocop:disable Metrics
          sig_dirs = [] #: Array[String]

          opts = OptionParser.new(BANNER)
          opts.on("--sig-dir DIR") { |dir| sig_dirs << dir }
          opts.parse!(args)

          if sig_dirs.empty?
            puts opts.help
          else
            envs = sig_dirs.map { |dir| load_env(dir) }
            env = merge_envs(envs)

            out = StringIO.new
            writer = Writer.new(out:)
            writer.write(env.declarations)

            puts out.string
          end
        end

        private

        # @rbs (String) -> Environment
        def load_env(dir)
          Environment.new.tap do |env|
            loader = EnvironmentLoader.new(core_root: nil)
            loader.add(path: Pathname(dir))
            loader.load(env:)
          end
        end

        # @rbs (Array[Environment]) -> Environment
        def merge_envs(others)
          Environment.new.tap do |env|
            others.each do |other|
              other.declarations.each do |decl|
                env << decl
              end
            end
          end
        end
      end
    end
  end
end
