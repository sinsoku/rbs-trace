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

            # Generate RBS files with rbs-inline.
            $ rbs-inline --output --opt-out app

            # Remove method definitions that have been migrated to inline comments.
            $ rbs subtract --write sig sig/generated/

          Options:
        USAGE

        # @rbs (Array[String]) -> void
        def run(args) # rubocop:disable Metrics
          sig_dir = nil
          rb_dir = nil

          opts = OptionParser.new(BANNER)
          opts.on("--sig-dir DIR") { |dir| sig_dir = dir }
          opts.on("--rb-dir DIR") { |dir| rb_dir = dir }
          opts.parse!(args)

          if sig_dir && rb_dir
            env = load_env(sig_dir) # steep:ignore ArgumentTypeMismatch
            decls = env.class_decls.transform_values { |v| v.primary.decl }

            Dir.glob("#{rb_dir}/**/*.rb").each do |path|
              file = File.new(path, decls)
              file.rewrite
            end
          else
            puts opts.help
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
