# Multi Redis

**Pattern to atomically execute redis operations in separate code units.**

[![Gem Version](https://badge.fury.io/rb/multi_redis.png)](http://badge.fury.io/rb/multi_redis)
[![Dependency Status](https://gemnasium.com/AlphaHydrae/multi_redis.png)](https://gemnasium.com/AlphaHydrae/multi_redis)
[![Build Status](https://secure.travis-ci.org/AlphaHydrae/multi_redis.png)](http://travis-ci.org/AlphaHydrae/multi_redis)
[![Coverage Status](https://coveralls.io/repos/AlphaHydrae/multi_redis/badge.png?branch=master)](https://coveralls.io/r/AlphaHydrae/multi_redis?branch=master)

## Installation

Put this in your Gemfile:

```rb
gem 'multi_redis', '~> 0.1.0'
```

Then run `bundle install`.

## Usage

Assume you have separate classes that use redis:

```rb
class RedisClass

  def initialize redis
    @redis = redis
  end
end

class MyFirstClass < RedisClass

  def do_stuff

    values = redis.multi do
      redis.get 'foo'
      redis.getset 'bar', 'newvalue'
    end

    "value 1 is #{values[0]}, value 2 is #{values[1]}"
  end
end

class MySecondClass < RedisClass

  def do_stuff
    value = redis.get 'baz'
    "value is #{value}"
  end
end

redis = Redis.new
redis.set 'key1', 'foo'
redis.set 'key2', 'bar'
redis.set 'key3', 'baz'

MyFirstClass.new(redis).do_stuff    #=> "value 1 is foo, value 2 is bar"
MySecondClass.new(redis).do_stuff   #=> "value is baz"
```

This works, but it would be faster if the redis operation in `MySecondClass` could be run in the same MULTI/EXEC block as the operations in `MyFirstClass`.
It would also be atomic, which might be interesting in some scenarios.

Multi Redis provides a pattern to structure such code so that your separate redis calls may be executed together.

```rb
redis = Redis.new
redis.set 'key1', 'foo'
redis.set 'key2', 'bar'
redis.set 'key3', 'baz'

# Set the client that Multi Redis operations will use.
MultiRedis.redis = redis

# Create a redis operation, i.e. an operation that performs redis calls.
redis_operation_1 = MultiRedis::Operation.new do

  # Multi blocks will be run atomically in a MULTI/EXEC.
  # All redis commands will return futures inside this block, so you can't use the values immediately.
  # Store futures in the provided data object for later use.
  multi do |data, redis|
    data.value1 = redis.get 'key1'
    data.value2 = redis.getset 'key2', 'newvalue'
  end

  # Run blocks are executed after the previous multi block (or blocks) are completed and all futures have been resolved.
  # The data object now contains the values of the futures you stored.
  run do |data|
    "value 1 is #{data.value1}, value 2 is #{data.value2}"
  end
end

# The return value of the operation is that of the last block.
# In this case, that's the return value of the run block.
result = redis_operation_1.execute   #=> "value 1 is foo, value 2 is bar"
```

Now let's define the second operation.

```rb
# Create another redis operation.
redis_operation_2 = MultiRedis::Operation.new do

  multi do |data, redis|
    data.value = redis.get 'key3'
  end

  run do |data|
    "value is #{data.value}"
  end
end

# If you run both operations through Multi Redis, their multi block
# will be executed in one MULTI/EXEC call to redis.
results = MultiRedis.execute redis_operation_1, redis_operation_2

# Resulting redis calls:
# - MULTI
# - GET foo
# - GETSET bar newvalue
# - GET baz
# - EXEC

# The final results of both operations are returned in an array.
results   #=> [ "value 1 is foo, value 2 is bar", "value is baz" ]

# This syntax is equivalent.
results = MultiRedis.execute do
  redis_operation_1.execute
  redis_operation_2.execute
end
results   #=> [ "value 1 is foo, value 2 is bar", "value is baz" ]
```

## Meta

* **Author:** Simon Oulevay (Alpha Hydrae)
* **License:** MIT (see [LICENSE.txt](https://raw.github.com/AlphaHydrae/multi_redis/master/LICENSE.txt))
