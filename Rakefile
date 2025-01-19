# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

desc "Generate rbs files"
task :rbs_inline do
  sh "rbs-inline --output --opt-out lib"

  # If the Ruby file is deleted, delete the RBS file
  Dir.glob("sig/generated/**/*.rbs").each do |path|
    rbs_path = Pathname(path)
    rb_path = rbs_path.sub(%r{^sig/generated}, "lib").sub_ext(".rb")
    rbs_path.delete unless File.exist?(rb_path)
  end
end

desc "Run Steep"
task :steep do
  sh "steep check"
end

task(default: %i[spec rubocop rbs_inline steep])
