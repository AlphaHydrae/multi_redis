module MultiRedis

  class Operation
    attr_accessor :redis
    attr_reader :steps, :future

    def initialize options = {}, &block

      @target = options[:target] || self
      @redis = options[:redis]
      @steps = []

      configure &block if block
    end

    def configure &block
      DSL.new(self).instance_eval &block
    end

    def execute *args
      if MultiRedis.executing?
        MultiRedis.executor.add self, *args
        @future = Future.new
      else
        e = Executor.new redis: @redis
        e.add self, *args
        e.execute.first.tap do |result|
          @future = Future.new result
        end
      end
    end

    def add type, &block
      raise ArgumentError, "Unknown type #{type}, must be one of #{TYPES.join ', '}." unless TYPES.include? type
      @steps << Step.new(@target, type, block)
    end

    private

    TYPES = [ :call, :pipelined, :multi ]

    class DSL

      def initialize op
        @op = op
      end

      def multi &block
        @op.add :multi, &block
      end

      def pipelined &block
        @op.add :pipelined, &block
      end

      def run &block
        @op.add :call, &block
      end
    end
  end
end
