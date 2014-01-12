
module RedisSpecHelper

  def key name
    "multi_redis:test:#{name}"
  end

  def number_of_redis_calls type = nil
    raise "#watch_redis_calls was not called" unless @redis_calls
    type ? @redis_calls[type].to_i : @redis_calls.inject(0){ |memo,(k,v)| memo + v }
  end

  def expect_redis_calls options = {}
    [ :call, :pipelined, :multi ].each do |type|
      expect(number_of_redis_calls(type)).to eq(options[type].to_i)
    end
    expect(number_of_redis_calls).to eq(options.inject(0){ |memo,(k,v)| memo + v })
  end

  def stub_and_call_original object, method, &block
    original = object.method method
    object.stub method do |*args,&run_block|
      block.call object
      original.call *args, &run_block
    end
  end

  private

  # This assumes that normal Redis calls go through the :call method of its client,
  # and that :multi and :pipelined don't. It might have to be updated if the Redis
  # implementation changes.
  def watch_redis_calls
    return if @redis_calls
    @redis_calls = { single: 0, multi: 0, pipelined: 0 }
    stub_and_call_original($redis.client, :call){ @redis_calls[:single] += 1 }
    stub_and_call_original($redis, :multi){ @redis_calls[:multi] += 1 }
    stub_and_call_original($redis, :pipelined){ @redis_calls[:pipelined] += 1 }
  end
end
