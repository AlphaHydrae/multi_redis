require 'ostruct'
require 'redis'
require 'thread'

module MultiRedis
  VERSION = '0.2.0'

  @redis = nil
  @mutex = Mutex.new
  @executing = false
  @operations = []
  @arguments = []

  def self.redis= redis
    @redis = redis
  end

  def self.redis
    @redis
  end

  def self.execute *args, &block

    operations, arguments = @mutex.synchronize do
      @operations = args.dup
      @arguments = []
      @executing = true
      yield if block_given?
      @executing = false
      [ @operations.dup.tap{ |ops| @operations.clear }, @arguments ]
    end

    Executor.new(operations, args: arguments).execute
  end

  def self.executing?
    @executing
  end

  def self.register_operation op, *args
    op.tap do |op|
      @operations << op
      @arguments << args
    end
  end

  module Extension

    def multi_redis_operation symbol, options = {}, &block
      op = Operation.new self, options, &block
      define_method symbol do |*args|
        op.execute *args
      end
      self
    end
  end

  class Executor
    
    def initialize operations, options = {}
      @operations = operations
      @arguments = options[:args] || []
      @redis = options[:redis]
    end

    def execute options = {}

      redis = @redis || MultiRedis.redis
      contexts = Array.new(@operations.length){ |i| Context.new redis }
      stacks = @operations.collect{ |op| op.steps.dup }
      args = stacks.collect.with_index{ |a,i| @arguments[i] || [] }
      final_results = Array.new @operations.length

      while stacks.any? &:any?

        # execute all non-multi steps
        stacks.each_with_index do |steps,i|
          final_results[i] = steps.shift.execute(contexts[i], args[i]) while steps.first && !steps.first.multi_type
        end

        # execute all pipelined steps, if any
        pipelined_steps = stacks.collect{ |steps| steps.first && steps.first.multi_type == :pipelined ? steps.shift : nil }
        if pipelined_steps.any?
          results = []
          redis.pipelined do
            pipelined_steps.each_with_index do |step,i|
              if step
                final_results[i] = step.execute(contexts[i], args[i])
                contexts[i].last_results = redis.client.futures[results.length, redis.client.futures.length]
                results += contexts[i].last_results
              end
            end
          end
          pipelined_steps.each_with_index{ |step,i| contexts[i].resolve_futures! if step }
        end

        # execute all multi steps, if any
        multi_steps = stacks.collect{ |steps| steps.first && steps.first.multi_type == :multi ? steps.shift : nil }
        if multi_steps.any?
          results = []
          redis.multi do
            multi_steps.each_with_index do |step,i|
              if step
                final_results[i] = step.execute(contexts[i], args[i])
                contexts[i].last_results = redis.client.futures[results.length, redis.client.futures.length]
                results += contexts[i].last_results
              end
            end
          end
          multi_steps.each_with_index{ |step,i| contexts[i].resolve_futures! if step }
        end
      end

      final_results
    end
  end

  class Operation
    attr_reader :steps

    def initialize *args, &block

      options = args.last.kind_of?(Hash) ? args.pop : {}

      @target = args.shift || options[:target] || self
      @redis = options[:redis]
      @steps = []

      DSL.new(self).instance_eval &block
    end

    def execute *args
      if MultiRedis.executing?
        MultiRedis.register_operation self, *args
      else
        Executor.new([ self ], args: [ args ], redis: @redis).execute.first
      end
    end

    def add_step multi_type = nil, &block
      @steps << Step.new(@target, multi_type, block)
    end

    class DSL

      def initialize op
        @op = op
      end

      def multi &block
        @op.add_step :multi, &block
      end

      def pipelined &block
        @op.add_step :pipelined, &block
      end

      def run &block
        @op.add_step &block
      end
    end
  end

  class Step

    def initialize target, multi_type, block
      @target, @multi_type, @block = target, multi_type, block
    end

    def execute context, *args
      @target.instance_exec *args.unshift(context), &@block
    end

    def multi_type
      @multi_type
    end
  end
end

Dir[File.join File.dirname(__FILE__), File.basename(__FILE__, '.*'), '*.rb'].each{ |lib| require lib }
