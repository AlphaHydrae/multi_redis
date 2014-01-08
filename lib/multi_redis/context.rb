
module MultiRedis

  class Context
    attr_accessor :last_results

    def initialize redis
      @last_results = []
      @data = Data.new
      @redis = redis
    end

    def redis
      @redis
    end

    def data
      @data
    end

    def resolve_futures!
      @data.contents.each_key do |k|
        @data.contents[k] = @data.contents[k].value if @data.contents[k].is_a? Redis::Future
      end
      @last_results.collect!{ |r| r.is_a?(Redis::Future) ? r.value : r }
    end
  end
end
