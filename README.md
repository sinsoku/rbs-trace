[![Gem Version](https://badge.fury.io/rb/rbs-trace.svg)](https://badge.fury.io/rb/rbs-trace)
[![Test](https://github.com/sinsoku/rbs-trace/actions/workflows/test.yml/badge.svg)](https://github.com/sinsoku/rbs-trace/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/sinsoku/rbs-trace/graph/badge.svg?token=rEsPe8Quyu)](https://codecov.io/gh/sinsoku/rbs-trace)

# RBS::Trace

RBS::Trace automatically collects argument and return types and saves RBS type declarations as RBS files or comments.

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

Call target methods within the `enable` method block, and call the `save_comments` method.

```ruby
trace = RBS::Trace.new

# Collects the types of methods called in the block.
trace.enable do
  user = User.new("Nanoha", "Takamachi")
  user.say_hello
end

# Save RBS type declarations as embedded comments
trace.save_comments
```

Automatically insert comments into the file.

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
RSpec.configure do |config|
  trace = RBS::Trace.new

  config.before(:suite) { trace.enable }
  config.after(:suite) do
    trace.disable
    trace.save_comments
  end
end
```

### Minitest

Add the following code to `test_helper.rb`.

```ruby
trace = RBS::Trace.new
trace.enable

Minitest.after_run do
  trace.disable
  trace.save_comments
end
```

## Tips

### Insert RBS declarations for specific files only

```ruby
trace.save_comments(only: Dir.glob("#{Dir.pwd}/app/models/**/*.rb"))
```

### Save RBS declarations as files

```ruby
trace.save_files(out_dir: "sig/trace/")
```

### Parallel testing

If you are using a parallel testing gem such as [parallel_tests](https://github.com/grosser/parallel_tests) or [flatware](https://github.com/briandunn/flatware), first save the type definitions in RBS files.

```ruby
trace.save_files(out_dir: "tmp/sig-#{ENV["TEST_ENV_NUMBER"]}")
```

Then use `rbs-trace merge` to merge multiple RBS files into one.

```bash
$ rbs-trace merge --sig-dir='tmp/sig-*' > sig/merged.rbs
```

Finally, insert comments using the merged RBS files.

```bash
$ rbs-trace inline --rb-dir=app --rb-dir=lib
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

Everyone interacting in the RBS::Trace project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/sinsoku/rbs-trace/blob/main/CODE_OF_CONDUCT.md).
