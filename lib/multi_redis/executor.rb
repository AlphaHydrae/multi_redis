module MultiRedis

  class Executor

    def initialize options = {}
      @operations = []
      @redis = options[:redis]
    end

    def add operation, *args
      @operations << { op: operation, args: args }
    end

    def execute options = {}

      redis = @redis || MultiRedis.redis
      shared_context = Context.new redis

      total = 0
      execution = @operations.collect do |operation|
        total += operation[:op].steps.length
        OperationExecution.new operation[:op], operation[:args], shared_context
      end

      while execution.any?{ |oe| !oe.done? } && total >= 1
        total -= 1 # safeguard against infinite loop

        TYPES.each do |type|

          execution.each do |oe|
            oe.execute_current_step while oe.next? :call
          end

          if execution.any?{ |oe| oe.next? type }
            shared_context.last_replies.clear
            redis.send type do
              execution.each do |oe|
                oe.execute_current_step if oe.next? type
              end
            end
            execution.each{ |oe| oe.resolve_futures! }
          end
        end
      end

      execution.each{ |oe| oe.resolve_operation_future! }
      execution.collect!{ |oe| oe.final_results }
    end

    private

    TYPES = [ :pipelined, :multi ]
    
    class OperationExecution
      attr_reader :final_results

      def initialize operation, args, shared_context

        @operation = operation
        @args = args

        @context = Context.new shared_context.redis, shared_context
        @steps = operation.steps

        @current_index = 0
      end

      def done?
        !current_step
      end

      def next? type
        current_step && current_step.type == type
      end

      def execute_current_step
        results = @context.execute current_step, *@args
        @current_index += 1
        @final_results = results
      end

      def resolve_futures!
        @context.resolve_futures!
      end

      def resolve_operation_future!
        @operation.future.value = @final_results if @operation.future
      end

      private

      def current_step
        @steps[@current_index]
      end
    end
  end
end
