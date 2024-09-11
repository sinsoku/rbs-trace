# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

desc "Generate rbs files"
task :rbs_inline do
  sh "rbs-inline --output --opt-out lib"
end

desc "Run Steep"
task :steep do
  sh "steep check"
end

default = if RUBY_VERSION.start_with?("3.3")
            %i[spec rubocop rbs_inline steep]
          else
            %i[spec rubocop]
          end
task(default:)
