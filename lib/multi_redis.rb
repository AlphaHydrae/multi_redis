require 'redis'

module MultiRedis
  VERSION = '0.2.0'

  class << self
    attr_accessor :redis
  end

  def self.execute *args, &block

    options = args.last.kind_of?(Hash) ? args.pop : {}

    executor = @mutex.synchronize do
      @executor = Executor.new options
      args.each{ |op| @executor.add op }
      yield if block_given?
      @executor
    end

    executor.execute
  end

  private

  @mutex = Mutex.new
  @executor = nil

  def self.executor
    @executor
  end

  def self.executing?
    !!@executor
  end
end

Dir[File.join File.dirname(__FILE__), File.basename(__FILE__, '.*'), '*.rb'].each{ |lib| require lib }
