require 'helper'

describe MultiRedis do

  it "should work" do

    $redis.set key('foo'), 1
    $redis.set key('bar'), key('baz')
    $redis.set key('baz'), 2

    expect($redis.client).not_to receive(:call)
    expect($redis).to receive(:multi).twice.and_call_original

    m = MultiRedis::Operation.new self, redis: $redis do

      multi do |data,redis|

        expect(redis).to be($redis)
        expect(data.last_results).to be_empty

        data.a = redis.get key('foo')
        redis.get key('baz')
        data.b = redis.get key('bar')
        data.c = 'string'
      end

      run do |data|

        expect(data).to be_data(a: '1', b: key('baz'), c: 'string', last_results: [ '1', '2', key('baz') ])

        data.d = 'another string'
      end

      multi do |data,redis|

        expect(redis).to be($redis)
        expect(data).to be_data(a: '1', b: key('baz'), c: 'string', d: 'another string', last_results: [ '1', '2', key('baz') ])

        data.e = redis.get data.b
      end

      run do |data|

        expect(data).to be_data(a: '1', b: key('baz'), c: 'string', d: 'another string', e: '2', last_results: [ '2' ])

        'result'
      end
    end

    expect(m.execute).to eq('result')
  end

  it "should combine multi blocks" do

    $redis.set key('foo'), 1
    $redis.set key('bar'), 2
    $redis.set key('baz'), 3

    expect($redis.client).not_to receive(:call)
    expect($redis).to receive(:multi).once.and_call_original

    op1 = MultiRedis::Operation.new self, redis: $redis do

      multi do |data,redis|
        data.a = redis.get key('foo')
        data.b = redis.get key('bar')
        expect(data.last_results).to be_empty
      end

      run do |data|
        expect(data.a).to eq('1')
        expect(data.b).to eq('2')
        expect(data.last_results).to eq([ '1', '2' ])
        'result1'
      end
    end

    op2 = MultiRedis::Operation.new self, redis: $redis do

      multi do |data,redis|
        data.c = redis.get key('baz')
        expect(data.last_results).to be_empty
      end

      run do |data|
        expect(data.c).to eq('3')
        expect(data.last_results).to eq([ '3' ])
        'result2'
      end
    end

    results = MultiRedis::Executor.new([ op1, op2 ], redis: $redis).execute

    expect(results).to eq([ 'result1', 'result2' ])
  end

  class TestClass
    extend MultiRedis::Extension
    extend RedisSpecHelper

    multi_redis_operation :op1 do

      multi do |data,redis|
        data.a = redis.get key('foo')
        data.b = redis.get key('bar')
      end

      run do |data|
        { d: data.a, e: data.b }
      end
    end

    multi_redis_operation :op2 do

      multi do |data,redis|
        data.c = redis.get key('baz')
      end

      run do |data|
        { f: data.c }
      end
    end
  end

  it "should provide extensions" do

    $redis.set key('foo'), 1
    $redis.set key('bar'), 2
    $redis.set key('baz'), 3
    MultiRedis.redis = $redis

    expect($redis.client).not_to receive(:call)
    expect($redis).to receive(:multi).once.and_call_original
    expect(MultiRedis::Operation).not_to receive(:new)

    o = TestClass.new

    results = MultiRedis.execute do
      o.op1
      o.op2
    end

    expect(results).to eq([ { d: '1', e: '2' }, { f: '3' } ])
  end
end
