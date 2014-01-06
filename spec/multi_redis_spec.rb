require 'helper'

describe MultiRedis do

  let(:test_redis){ Redis.new }

  it "should work" do

    test_redis.set 'foo', 1
    test_redis.set 'bar', 'baz'
    test_redis.set 'baz', 2

    m = MultiRedis::Operation.new self, redis: test_redis do

      multi do |redis,data|

        expect(redis).to be(test_redis)
        expect(data).not_to be_nil
        expect(data.to_a).to be_empty

        data.a = redis.get 'foo'
        redis.get 'baz'
        data.b = redis.get 'bar'
      end

      run do |data|
        expect(data.a).to eq('1')
        expect(data.b).to eq('baz')
        expect(data.to_a).to eq([ '1', '2', 'baz' ])
      end

      multi do |redis,data|

        expect(redis).to be(test_redis)
        expect(data.a).to eq('1')
        expect(data.b).to eq('baz')
        expect(data.to_a).to eq([ '1', '2', 'baz' ])

        data.c = redis.get data.b
      end

      run do |data|
        expect(data.a).to eq('1')
        expect(data.b).to eq('baz')
        expect(data.c).to eq('2')
        expect(data.to_a).to eq([ '2' ])
      end
    end

    m.execute
  end
end
