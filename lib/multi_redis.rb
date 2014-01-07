require 'ostruct'
require 'redis'
require 'thread'

module MultiRedis
  VERSION = '0.1.0'

  @redis = nil
  @mutex = Mutex.new
  @executing = false
  @operations = []

  def self.redis= redis
    @redis = redis
  end

  def self.redis
    @redis
  end

  def self.execute *args, &block

    operations = @mutex.synchronize do
      @operations = args
      @executing = true
      yield if block_given?
      @executing = false
      @operations.dup.tap{ |ops| @operations.clear }
    end

    Executor.new(operations).execute
  end

  def self.executing?
    @executing
  end

  def self.register_operation op
    op.tap{ |op| @operations << op }
  end

  module Extension

    def multi_redis_operation symbol, options = {}, &block
      op = Operation.new self, options, &block
      define_method symbol do |*args|
        op.execute *args
      end
    end
  end

  class Executor
    
    def initialize operations, options = {}
      @operations = operations
      @redis = options[:redis]
    end

    def execute

      redis = @redis || MultiRedis.redis
      data = Array.new(@operations.length){ |i| Data.new }
      stacks = @operations.collect{ |op| op.steps.dup }
      final_results = Array.new @operations.length

      while stacks.any? &:any?

        # execute all non-multi steps
        stacks.each_with_index{ |steps,i| final_results[i] = steps.shift.execute data[i], redis while steps.first && !steps.first.multi_type }

        # execute all pipelined steps, if any
        pipelined_steps = stacks.collect{ |steps| steps.first && steps.first.multi_type == :pipelined ? steps.shift : nil }
        if pipelined_steps.any?
          results = []
          redis.pipelined do
            pipelined_steps.each_with_index do |step,i|
              if step
                final_results[i] = step.execute data[i], redis
                data[i].last_results = redis.client.futures[results.length, redis.client.futures.length]
                results += data[i].last_results
              end
            end
          end
          pipelined_steps.each_with_index{ |step,i| data[i].resolve_futures! if step }
        end

        # execute all multi steps, if any
        multi_steps = stacks.collect{ |steps| steps.first && steps.first.multi_type == :multi ? steps.shift : nil }
        if multi_steps.any?
          results = []
          redis.multi do
            multi_steps.each_with_index do |step,i|
              if step
                final_results[i] = step.execute data[i], redis
                data[i].last_results = redis.client.futures[results.length, redis.client.futures.length]
                results += data[i].last_results
              end
            end
          end
          multi_steps.each_with_index{ |step,i| data[i].resolve_futures! if step }
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

    def execute
      if MultiRedis.executing?
        MultiRedis.register_operation self
      else
        Executor.new([ self ], redis: @redis).execute.first
      end
    end

    def add_step klass, block
      @steps << klass.new(@target, block)
    end

    class DSL

      def initialize op
        @op = op
      end

      def multi &block
        @op.add_step MultiStep, block
      end

      def pipelined &block
        @op.add_step PipelinedStep, block
      end

      def run &block
        @op.add_step Step, block
      end
    end
  end

  class Step

    def initialize target, block
      @target, @block = target, block
    end

    def execute data, redis
      @target.instance_exec data, &@block
    end

    def multi_type
      nil
    end
  end

  class MultiStep < Step

    def execute data, redis
      @target.instance_exec data, redis, &@block
    end

    def multi_type
      :multi
    end
  end

  class PipelinedStep < MultiStep

    def multi_type
      :pipelined
    end
  end

  class Data
    attr_accessor :last_results

    def initialize
      @last_results = []
      @data = Hash.new
    end

    def [] k
      @data[k]
    end

    def []= k, v
      @data[k] = v
    end

    def method_missing symbol, *args, &block
      if @data.key? symbol
        @data[symbol]
      elsif m = symbol.to_s.match(/\A(.*)\=\Z/)
        raise "Reserved name" if respond_to? acc = m[1].to_sym
        @data[acc] = args[0]
      else
        super symbol, *args, &block
      end
    end

    def resolve_futures!
      @data.each_key do |k|
        @data[k] = @data[k].value if @data[k].is_a? Redis::Future
      end
      @last_results.collect!{ |r| r.is_a?(Redis::Future) ? r.value : r }
    end
  end
end

#Dir[File.join File.dirname(__FILE__), File.basename(__FILE__, '.*'), '*.rb'].each{ |lib| require lib }
