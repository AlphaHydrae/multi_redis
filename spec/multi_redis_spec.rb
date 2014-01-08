require 'helper'

describe MultiRedis do

  it "should work" do

    $redis.set key('foo'), 1
    $redis.set key('bar'), key('baz')
    $redis.set key('baz'), 2

    expect($redis.client).not_to receive(:call)
    expect($redis).to receive(:multi).twice.and_call_original

    m = MultiRedis::Operation.new self, redis: $redis do

      multi do |mr|

        expect(mr.redis).to be($redis)
        expect(mr.last_results).to be_empty

        mr.data.a = mr.redis.get key('foo')
        mr.redis.get key('baz')
        mr.data.b = mr.redis.get key('bar')
        mr.data.c = 'string'
      end

      run do |mr|

        expect(mr).to have_data(a: '1', b: key('baz'), c: 'string', last_results: [ '1', '2', key('baz') ])

        mr.data.d = 'another string'
      end

      multi do |mr|

        expect(mr.redis).to be($redis)
        expect(mr).to have_data(a: '1', b: key('baz'), c: 'string', d: 'another string', last_results: [ '1', '2', key('baz') ])

        mr.data.e = mr.redis.get mr.data.b
      end

      run do |mr|

        expect(mr).to have_data(a: '1', b: key('baz'), c: 'string', d: 'another string', e: '2', last_results: [ '2' ])

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

      multi do |mr|
        mr.data.a = mr.redis.get key('foo')
        mr.data.b = mr.redis.get key('bar')
        expect(mr.last_results).to be_empty
      end

      run do |mr|
        expect(mr.data.a).to eq('1')
        expect(mr.data.b).to eq('2')
        expect(mr.last_results).to eq([ '1', '2' ])
        'result1'
      end
    end

    op2 = MultiRedis::Operation.new self, redis: $redis do

      multi do |mr|
        mr.data.c = mr.redis.get key('baz')
        expect(mr.last_results).to be_empty
      end

      run do |mr|
        expect(mr.data.c).to eq('3')
        expect(mr.last_results).to eq([ '3' ])
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

      multi do |mr|
        mr.data.a = mr.redis.get key('foo')
        mr.data.b = mr.redis.get key('bar')
      end

      run do |mr|
        { d: mr.data.a, e: mr.data.b }
      end
    end

    multi_redis_operation :op2 do

      multi do |mr|
        mr.data.c = mr.redis.get key('baz')
      end

      run do |mr|
        { f: mr.data.c }
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
