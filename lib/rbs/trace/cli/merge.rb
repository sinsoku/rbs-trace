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

            # Or you can specify a glob pattern.
            $ rbs-trace merge --sig-dir=tmp/sig-*

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
            envs = sig_dirs.flat_map { |sig_dir| Dir.glob(sig_dir) }
                           .map { |dir| load_env(dir) }
            env = merge_envs(envs)

            out = StringIO.new
            writer = Writer.new(out:)
            writer.write(env.declarations)

            puts out.string
          end
        end

        # @rbs (Array[Environment]) -> Environment
        def merge_envs(others) # rubocop:disable Metrics
          Environment.new.tap do |env|
            others.each do |other|
              other.declarations.each do |decl|
                next unless decl.is_a?(AST::Declarations::Class) || decl.is_a?(AST::Declarations::Module)

                entry = env.module_class_entry(decl.name.absolute!)

                if entry.is_a?(Environment::MultiEntry)
                  decl.members.each { |member| merge(entry.primary.decl, member) }
                else
                  env << decl
                end
              end
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

        def merge(decl, member) # rubocop:disable Metrics
          case member
          when AST::Declarations::Class, AST::Declarations::Module
            d = decl.members.find { |m| m.is_a?(member.class) && m.name == member.name }

            if d
              member.members.each { |m| merge(d, m) }
            else
              decl.members << member
            end
          when AST::Members::MethodDefinition
            found = decl.members.find { |m| m.is_a?(member.class) && m.name == member.name && m.kind == member.kind }

            if found
              (member.overloads - found.overloads).each do |overload|
                found.overloads << overload
              end
            else
              decl.members << member
            end
          else
            decl.members << member unless decl.members.include?(member)
          end
        end
      end
    end
  end
end
