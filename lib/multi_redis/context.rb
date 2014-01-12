module MultiRedis

  class Context
    attr_accessor :last_result
    attr_accessor :last_replies

    def initialize redis, shared_context = nil
      @redis = redis
      @data = Data.new
      @last_replies = []
      @shared_context = shared_context
    end

    def execute operation, *args
      @last_result = operation.execute self, *args
      if @resolve = @redis.client.respond_to?(:futures)
        @last_replies = @redis.client.futures[@shared_context.last_replies.length, @redis.client.futures.length]
        @shared_context.last_replies.concat @last_replies
      end
      @shared_context.last_result = @last_result
      @last_result
    end

    def shared
      @shared_context
    end

    def redis
      @redis
    end

    def data
      @data
    end

    def resolve_futures!
      return unless @resolve
      @data.each_key do |k|
        @data[k] = @data[k].value if @data[k].is_a? Redis::Future
      end
      @last_replies.collect!{ |r| r.is_a?(Redis::Future) ? r.value : r }
    end
  end
end
