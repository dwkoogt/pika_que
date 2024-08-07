# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pika_que/version'

Gem::Specification.new do |spec|
  spec.name          = "pika_que"
  spec.version       = PikaQue::VERSION
  spec.authors       = ["Dong Wook Koo"]
  spec.email         = ["dwkoogt@gmail.com"]

  spec.summary       = %q{Ruby background processor for RabbitMQ.}
  spec.description   = %q{Ruby background processor for RabbitMQ.}
  spec.homepage      = "https://github.com/dwkoogt/pika_que"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  # if spec.respond_to?(:metadata)
  #   spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  # else
  #   raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  # end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'bunny', '~> 2.19.0'
  spec.add_dependency 'concurrent-ruby', '~> 1.0'
  spec.add_dependency 'json', '~> 1.8'
  spec.add_dependency 'dry-inflector'

  spec.add_development_dependency "bundler", "~> 2.1.4"
  spec.add_development_dependency "rake", "~> 12.3.0"
  spec.add_development_dependency "rspec", "~> 3.7.0"
  spec.add_development_dependency "simplecov", "~> 0.16.1"
end
