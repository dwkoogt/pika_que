# PikaQue

A RabbitMQ background processing framework for Ruby with built-in support for Rails integration.

PikaQue is inspired by Sneakers, Hutch, and Sidekiq. It is intended to implement more support for Rails a la Sidekiq.
It supports retry (both constant and exponential backoffs) and delayed/scheduled execution.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pika_que'
```

Or install it yourself as:

    $ gem install pika_que

## Usage

To create a worker:

```ruby
class PokeWorker
  include PikaQue::Worker
  from_queue "poke"

  def perform(msg)
    # do something with msg["greeting"]
    ack!
  end
end
```

To enqueue a job:

```ruby
PokeWorker.enqueue({ greeting: "I Challenge You!" })
```

To run server:

    $ bundle exec pika_que
    

### Rails and ActiveJob Quickstart

Create workers(not required for ActiveJob) in:

    app/workers
    
Create a config file `pika_que.yml` in config:

    config/pika_que.yml
    
```yml
# pika_que.yml
processors:
  - workers:
    - queue: default
    - queue: mailers
    - queue: your-active-job-queue-name
  - workers:
    - worker: PokeWorker

```

Set the backend for active job in `config/application.rb`:

    config.active_job.queue_adapter = :pika_que

Then run the server.

For more details, see [wiki](https://github.com/dwkoogt/pika_que/wiki/Rails-Setup).

### Examples

See examples for more usage reference.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment. Run `bundle exec pika_que` to use the gem in this directory, ignoring other installed copies of this gem.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dwkoogt/pika_que. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

