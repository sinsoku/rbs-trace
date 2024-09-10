# frozen_string_literal: true

require_relative "lib/rbs/trace/version"

Gem::Specification.new do |spec|
  spec.name = "rbs-trace"
  spec.version = RBS::Trace::VERSION
  spec.authors = ["Takumi Shotoku"]
  spec.email = ["sinsoku.listy@gmail.com"]

  spec.summary = "Automatically Insert inline RBS type declarations using runtime information."
  spec.description = <<~DESCRIPTION
    RBS::Trace collects argument types and return value types using TracePoint, and inserts
    inline RBS type declarations into files.
  DESCRIPTION
  spec.homepage = "https://github.com/sinsoku/rbs-trace"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/v#{spec.version}"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/v#{spec.version}/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "prism", ">= 0.3.0"
end
