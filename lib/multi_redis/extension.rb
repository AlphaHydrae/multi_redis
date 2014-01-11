module MultiRedis

  module Extension

    def multi_redis_operation symbol, options = {}, &block
      op = Operation.new options.merge(target: self), &block
      define_method symbol do |*args|
        op.execute *args
      end
      self
    end
  end
end
