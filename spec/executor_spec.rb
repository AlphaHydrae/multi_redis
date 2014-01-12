require 'helper'

describe MultiRedis::Executor do
  let(:operations){ [] }

  it "should execute pipelined and multi steps together" do

    $redis.set key('foo'), '42'
    $redis.set key('bar'), '66'
    $redis.set key('baz'), 'fu'

    op1 = MultiRedis::Operation.new target: self do

      pipelined do |mr|
        operations << 10
        mr.redis.get key('foo')
      end

      run do |mr|
        operations << 11
        expect(mr.last_replies).to eq([ '42' ])
      end

      multi do |mr|
        operations << 12
        mr.data.d = mr.redis.incrby key('foo'), 24
      end

      run do |mr|
        operations << 13
        expect(mr.last_replies).to eq([ 66 ])
        expect(mr.data.d).to eq(66)
        mr.data
      end
    end

    op2 = MultiRedis::Operation.new target: self do

      pipelined do |mr|
        operations << 20
        mr.data.a = mr.redis.getset key('bar'), 24
      end

      run do |mr|
        operations << 21
        expect(mr.last_replies).to eq([ '66' ])
        expect(mr.data.a).to eq('66')
        expect(mr.redis.get(key('bar'))).to eq('24')
      end

      run do |mr|
        operations << 22
      end

      multi do |mr|
        operations << 23
        mr.data.e = mr.redis.incrby key('foo'), 34
        mr.redis.decr key('foo')
      end

      run do |mr|
        operations << 24
        expect(mr.last_replies).to eq([ 100, 99 ])
        expect(mr.data.e).to eq(100)
        mr.data
      end
    end

    op3 = MultiRedis::Operation.new target: self do

      run do |mr|
        operations << 30
      end

      run do |mr|
        operations << 31
      end

      run do |mr|
        operations << 32
      end

      pipelined do |mr|
        operations << 33
        mr.data.b = mr.redis.append key('baz'), 'bar'
        mr.data.c = mr.redis.get key('foo')
      end

      multi do |mr|
        operations << 34
        expect(mr.last_replies).to eq([ 5, '42' ])
        expect(mr.data.b).to eq(5)
        expect(mr.data.c).to eq('42')
        mr.redis.set key('baz'), 'qux'
      end

      run do |mr|
        operations << 35
        expect(mr.last_replies).to eq([ "OK" ])
        mr.data
      end
    end

    subject.add op1
    subject.add op2
    subject.add op3

    watch_redis_calls
    results = subject.execute
    expect_redis_calls call: 1, pipelined: 1, multi: 1

    expect(operations).to eq([
      30, 31, 32, # run blocks before the first pipelined block
      10, 20, 33, # the three pipelined blocks
      11, 21, 22, # run blocks between the pipelined and multi blocks
      12, 23, 34, # the three multi blocks
      13, 24, 35  # the remaining run blocks
    ])

    expect(results[0]).to eq(d: 66)
    expect(results[1]).to eq(a: '66', e: 100)
    expect(results[2]).to eq(b: 5, c: '42')
  end
end
