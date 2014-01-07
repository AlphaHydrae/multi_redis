require 'rubygems'
require 'bundler'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'simplecov'
require 'coveralls'
Coveralls.wear!

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]

require 'rspec'
require 'set'

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|

  config.include RedisSpecHelper

  config.before :suite do
    $redis = Redis.new
  end

  config.before :each do
    keys = $redis.keys 'multi_redis:test:*'
    $redis.del *keys if keys.any?
  end

  config.after :suite do
    keys = $redis.keys 'multi_redis:test:*'
    $redis.del *keys if keys.any?
  end
end

require 'multi_redis'
