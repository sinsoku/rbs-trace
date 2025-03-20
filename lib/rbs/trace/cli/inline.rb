# frozen_string_literal: true

module RBS
  class Trace
    class CLI
      class Inline
        BANNER = <<~USAGE
          Usage: rbs-trace inline --sig-dir=DIR --rb-dir=DIR

          Insert RBS inline comments from RBS files.

          Examples:
            # Insert inline comments to `app/**/*.rb`.
            $ rbs-trace inline --sig-dir=sig --rb-dir=app

          Options:
        USAGE

        # @rbs (Array[String]) -> void
        def run(args) # rubocop:disable Metrics
          sig_dir = Pathname.pwd.join("sig").to_s
          rb_dirs = [] #: Array[String]

          opts = OptionParser.new(BANNER)
          opts.on("--sig-dir DIR") { |dir| sig_dir = dir }
          opts.on("--rb-dir DIR") { |dir| rb_dirs << dir }
          opts.parse!(args)

          if rb_dirs.empty?
            puts opts.help
          else
            env = load_env(sig_dir) # steep:ignore ArgumentTypeMismatch
            decls = env.class_decls.transform_values { |v| v.primary.decl }

            rb_files = rb_dirs.flat_map { |rb_dir| Dir.glob("#{rb_dir}/**/*.rb") }
            rb_files.each do |path|
              file = File.new(path, decls)
              file.rewrite
            end
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
      end
    end
  end
end
