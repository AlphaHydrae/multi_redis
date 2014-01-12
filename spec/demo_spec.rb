require 'helper'

describe MultiRedis do
  before(:each){ MultiRedis.redis = $redis }

  it "should execute an operation's steps in order" do

    calls = []
    blocks = Array.new(6){ |i| lambda{ |mr| calls << i } }
    
    # Run, pipelined and multi blocks will be run in the order they are defined.
    MultiRedis::Operation.new do
      run &blocks[0]
      pipelined &blocks[1]
      run &blocks[2]
      pipelined &blocks[3]
      multi &blocks[4]
      run &blocks[5]
    end.execute

    expect(calls).to eq([ 0, 1, 2, 3, 4, 5 ])
  end

  it "should execute pipelined operations in the same pipeline" do

    # Set up some data.
    $redis.set key('foo'), 'bar'
    $redis.set key('baz'), 'qux'

    # A pipelined operation.
    op1 = MultiRedis::Operation.new target: self do
      pipelined{ |mr| mr.redis.get key('foo') }
      run{ |mr| mr.last_results.first }
    end

    # Another pipelined operation.
    op2 = MultiRedis::Operation.new target: self do
      pipelined{ |mr| mr.redis.get key('baz') }
      run{ |mr| mr.last_results.first }
    end

    watch_redis_calls

    # Execute both operations together.
    results = MultiRedis.execute op1, op2

    expect_redis_calls pipelined: 1

    expect(results[0]).to eq('bar')
    expect(results[1]).to eq('qux')
  end

  it "should provide a data object that automatically resolves futures" do

    $redis.set key('foo'), 1
    $redis.set key('bar'), key('baz')
    $redis.set key('baz'), 2

    m = MultiRedis::Operation.new target: self do

      multi do |mr|

        expect(mr.last_results).to be_empty

        mr.data.a = mr.redis.get key('foo')
        mr.redis.get key('baz')
        mr.data.b = mr.redis.get key('bar')
        mr.data.c = 'string'
      end

      run do |mr|

        expect(mr.last_results).to eq([ '1', '2', key('baz') ])

        expect(mr.data.a).to eq('1')
        expect(mr.data.b).to eq(key('baz'))
        expect(mr.data.c).to eq('string')

        mr.data.d = 'another string'
      end

      multi do |mr|

        expect(mr.last_results).to eq([ '1', '2', key('baz') ])

        expect(mr.data.a).to eq('1')
        expect(mr.data.b).to eq(key('baz'))
        expect(mr.data.c).to eq('string')
        expect(mr.data.d).to eq('another string')

        mr.data.e = mr.redis.get mr.data.b
      end

      run do |mr|

        expect(mr.last_results).to eq([ '2' ])

        expect(mr.data.a).to eq('1')
        expect(mr.data.b).to eq(key('baz'))
        expect(mr.data.c).to eq('string')
        expect(mr.data.d).to eq('another string')
        expect(mr.data.e).to eq('2')

        'result'
      end
    end

    watch_redis_calls
    result = m.execute
    expect_redis_calls multi: 2

    expect(result).to eq('result')
  end

  it "should combine multi blocks" do

    $redis.set key('foo'), 1
    $redis.set key('bar'), 2
    $redis.set key('baz'), 3

    op1 = MultiRedis::Operation.new target: self do

      multi do |mr|
        expect(mr.last_results).to be_empty
        mr.data.a = mr.redis.get key('foo')
        mr.data.b = mr.redis.get key('bar')
      end

      run do |mr|
        expect(mr.last_results).to eq([ '1', '2' ])
        expect(mr.data.a).to eq('1')
        expect(mr.data.b).to eq('2')
        'result1'
      end
    end

    op2 = MultiRedis::Operation.new target: self do

      multi do |mr|
        expect(mr.last_results).to be_empty
        mr.data.c = mr.redis.get key('baz')
      end

      run do |mr|
        expect(mr.last_results).to eq([ '3' ])
        expect(mr.data.c).to eq('3')
        'result2'
      end
    end

    watch_redis_calls
    results = MultiRedis.execute op1, op2
    expect_redis_calls multi: 1

    expect(results).to eq([ 'result1', 'result2' ])
  end

  class TestClass
    extend MultiRedis::Extension
    extend RedisSpecHelper

    multi_redis_operation :op1 do

      multi do |mr|
        mr.data.merge! a: mr.redis.get(key('foo')), b: mr.redis.get(key('bar'))
      end
    end

    multi_redis_operation :op2 do

      multi do |mr|
        mr.data.merge! c: mr.redis.get(key('baz'))
      end
    end
  end

  it "should provide extensions" do

    $redis.set key('foo'), 1
    $redis.set key('bar'), 2
    $redis.set key('baz'), 3

    expect($redis.client).not_to receive(:call)
    expect($redis).to receive(:multi).once.and_call_original
    expect(MultiRedis::Operation).not_to receive(:new)

    o = TestClass.new

    results = MultiRedis.execute do
      o.op1
      o.op2
    end

    expect(results).to eq([ { a: '1', b: '2' }, { c: '3' } ])
  end
end
