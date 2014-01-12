module MultiRedis

  class Context
    attr_accessor :last_results
    # TODO: add return value of last block

    def initialize redis
      @last_results = []
      @data = Data.new
      @redis = redis
    end

    def execute shared_results, operation, *args
      operation_result = operation.execute self, *args
      if @resolve = @redis.client.respond_to?(:futures)
        @last_results = @redis.client.futures[shared_results.length, @redis.client.futures.length]
        shared_results.concat @last_results
      end
      operation_result
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
      @last_results.collect!{ |r| r.is_a?(Redis::Future) ? r.value : r }
    end
  end
end
