require 'ostruct'
require 'redis'

module MultiRedis
  VERSION = '0.1.0'

  class Operation

    def initialize *args, &block

      options = args.last.kind_of?(Hash) ? args.pop : {}

      @target = args.shift || self
      @redis = options[:redis] || Redis.new
      @data = Data.new
      @block = block
    end

    def execute
      instance_eval &@block
    end

    def multi &block
      @data.to_a = @redis.multi do
        @target.instance_exec @redis, @data, &block
      end
      @data.resolve_futures!
    end

    def run &block
      @target.instance_exec @data, &block
    end
  end

  class Data

    def initialize
      @data = Hash.new
      @results = []
    end

    def method_missing symbol, *args, &block
      if m = symbol.to_s.match(/\A(.*)\=\Z/)
        @data[m[1].to_sym] = args[0]
      else
        super symbol, *args, &block
      end
    end

    def resolve_futures!
      @data.each_key do |k|
        self.class.send(:define_method, k){ @data[k].value } if @data[k].is_a? Redis::Future
        #@data[k] = @data[k].value if @data[k].is_a? Redis::Future
      end
    end

    def to_a
      @results
    end

    def to_a= results
      @results = results
    end
  end
end

#Dir[File.join File.dirname(__FILE__), File.basename(__FILE__, '.*'), '*.rb'].each{ |lib| require lib }
