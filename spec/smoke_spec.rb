# frozen_string_literal: true

RSpec.describe "Smoke Tests" do
  def system!(*args)
    system(*args, exception: true)
  end

  def tmp_repo(repo:, ref:, &)
    Dir.mktmpdir(nil, "tmp") do |dir|
      Dir.chdir(dir) do
        system! "git clone --branch #{ref} --depth 1 https://github.com/#{repo} ."
        Bundler.with_unbundled_env(&)
      end
    end
  end

  def add_rbs_trace_to_gemfile
    gem_path = File.expand_path("..", __dir__)
    File.open("Gemfile", "a") do |f|
      f.puts("gem 'rbs-trace', path: '#{gem_path}'")
    end
  end

  describe "Redmine", skip: ENV["SMOKE_TEST_REDMINE"].nil? do
    subject(:run_tests) do
      tmp_repo(repo: "redmine/redmine", ref: version) do
        add_rbs_trace_to_gemfile

        File.write("config/database.yml", <<~YAML)
          default: &default
            adapter: sqlite3
            pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
            timeout: 5000

          development:
            <<: *default
            database: db/development.sqlite3

          test:
            <<: *default
            database: db/test.sqlite3
        YAML
        File.open("test/test_helper.rb", "a") do |f|
          f.write(<<~RUBY)
            tracing = RBS::Trace::MethodTracing.new(log_level: :debug, raises: true)
            tracing.enable

            Minitest.after_run do
              tracing.disable
              tracing.insert_rbs
              tracing.save_rbs("sig/trace/")
            end
          RUBY
        end

        system! "bundle install"
        system! "bin/rails db:migrate"
        system! "bin/rails test --fail-fast --seed 0"
      end
    end

    let(:version) { "6.0.2" }

    before do
      # refs: https://github.com/redmine/redmine/blob/6.0.2/Gemfile#L3
      if RUBY_VERSION.start_with?("3.4")
        puts "Redmine v#{version} does not support Ruby v3.4."
        raise
      end
    end

    it "runs tests with rbs-trace enabled" do
      expect { run_tests }.not_to raise_error
    end
  end

  describe "Mastodon", skip: ENV["SMOKE_TEST_MASTODON"].nil? do
    subject(:run_tests) do
      tmp_repo(repo: "mastodon/mastodon", ref: version) do
        add_rbs_trace_to_gemfile

        File.open("spec/rails_helper.rb", "a") do |f|
          f.write(<<~RUBY)
            RSpec.configure do |config|
              tracing = RBS::Trace::MethodTracing.new(log_level: :debug, raises: true)

              config.before(:suite) { tracing.enable }
              config.after(:suite) do
                tracing.disable
                tracing.insert_rbs
                tracing.save_rbs("sig/trace/")
              end
            end
          RUBY
        end

        env = {
          "DISABLE_SIMPLECOV" => "true",
          "RAILS_ENV" => "test"
        }
        system! env, "bin/setup"
        system! env, "bin/flatware fan bin/rails db:test:prepare"
        system! env, "bin/rails assets:precompile"
        system! env, "bin/flatware rspec -r ./spec/flatware_helper.rb --fail-fast --seed 0"
      end
    end

    let(:version) { "v4.3.2" }

    before do
      # refs: https://github.com/mastodon/mastodon/blob/v4.3.2/.ruby-version
      if RUBY_VERSION != "3.3.5"
        puts "Mastodon #{version} support Ruby v3.3.5 only."
        raise
      end
    end

    it "runs tests with rbs-trace enabled" do
      expect { run_tests }.not_to raise_error
    end
  end
end
