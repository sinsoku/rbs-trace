# RBS::Trace

RBS::Trace collects argument types and return value types using TracePoint, and inserts inline RBS type declarations into files.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add rbs-trace

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install rbs-trace

## Usage

For example, suppose you have the following class:

```ruby
class User
  def initialize(first_name, last_name)
    @first_name = first_name
    @last_name = last_name
  end

  def full_name
    "#{@first_name} #{@last_name}"
  end

  def say_hello
    puts "hi, #{full_name}."
  end
end
```

Call target methods within the `enable` method block, and call the `insert_rbs` method.

```ruby
tracing = RBS::Trace::MethodTracing.new

# Collects the types of methods called in the block.
tracing.enable do
  user = User.new("Nanoha", "Takamachi")
  user.say_hello
end

tracing.insert_rbs
```

Automatically inserts inline RBS definitions into the file.

```ruby
class User
  # @rbs (String, String) -> void
  def initialize(first_name, last_name)
    @first_name = first_name
    @last_name = last_name
  end

  # @rbs () -> String
  def full_name
    "#{@first_name} #{@last_name}"
  end

  # @rbs () -> void
  def say_hello
    puts "hi, #{full_name}."
  end
end
```

## Integration

### RSpec

Add the following code to `spec/support/rbs_trace.rb`.

```ruby
return unless ENV["RBS_TRACE"]

RSpec.configure do |config|
  tracing = RBS::Trace::MethodTracing.new

  config.before(:suite) { tracing.enable }
  config.after(:suite) do
    tracing.disable
    tracing.insert_rbs
  end
end
```

Then run RSpec with the environment variables.

```console
$ RBS_TRACE=1 bundle exec rspec
```

## Tips

### Insert RBS declarations for specific files only

```ruby
tracing.files.each do |path, file|
  file.rewrite if path.include?("app/models/")
end
```

### Enable debug logging

If you want to enable debug logging, specify the environment variable `RBS_TRACE_DEBUG`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sinsoku/rbs-trace. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/sinsoku/rbs-trace/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Rbs::Trace project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/sinsoku/rbs-trace/blob/main/CODE_OF_CONDUCT.md).
