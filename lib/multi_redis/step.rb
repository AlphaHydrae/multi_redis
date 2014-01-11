module MultiRedis

  class Step

    def initialize target, type, block
      @target, @type, @block = target, type, block
    end

    def execute context, *args
      @target.instance_exec *args.unshift(context), &@block
    end

    def type
      @type
    end
  end
end
