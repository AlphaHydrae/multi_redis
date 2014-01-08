# Multi Redis

**Pattern to execute separate [redis-rb](https://github.com/redis/redis-rb) operations in the same command pipeline or multi/exec.**

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

Assume you have two separate methods that call redis:

```rb
$redis = Redis.new
$redis.set 'key1', 'foo'
$redis.set 'key2', 'bar'
$redis.set 'key3', 'baz'

class MyRedisClass

  def do_stuff

    # run two calls atomically in a MULTI/EXEC
    values = $redis.multi do
      $redis.get 'key1'
      $redis.getset 'key2', 'newvalue'
    end

    "value 1 is #{values[0]}, value 2 is #{values[1]}"
  end

  def do_other_stuff
    value = $redis.get 'key3'
    "hey #{value}"
  end
end

o = MyRedisClass.new
o.do_stuff         #=> "value 1 is foo, value 2 is bar"
o.do_other_stuff   #=> "hey baz"
```

This works, but the redis client executes two separate requests to the server:

```
Request 1:
- MULTI
- GET foo
- GETSET bar newvalue
- EXEC

Request 2:
- GET baz
```

The client will wait for the response from the first request before starting the second one.
One round trip could be saved by executing the second request in the same MULTI/EXEC block.
But it would be hard to refactor these two methods to do that while still keeping them separate.

Multi Redis provides a pattern to structure this code so that your separate redis calls may be executed together in one request when needed.

```rb
$redis = Redis.new
$redis.set 'key1', 'foo'
$redis.set 'key2', 'bar'
$redis.set 'key3', 'baz'

# Create a redis operation, i.e. an operation that performs redis calls.
do_stuff = MultiRedis::Operation.new do

  # Multi blocks will be run atomically in a MULTI/EXEC.
  # All redis commands will return futures inside this block, so you can't use the values immediately.
  # Store futures in the provided data object for later use.
  multi do |mr|
    mr.data.value1 = $redis.get 'key1'
    mr.data.value2 = $redis.getset 'key2', 'newvalue'
  end

  # Run blocks are executed after the previous multi block (or blocks) are completed and all futures have been resolved.
  # The data object now contains the values of the futures you stored.
  run do |mr|
    "value 1 is #{mr.data.value1}, value 2 is #{mr.data.value2}"
  end
end

# The return value of the operation is that of the last run block.
result = do_stuff.execute   #=> "value 1 is foo, value 2 is bar"

# Create the other redis operation.
do_other_stuff = MultiRedis::Operation.new do

  multi do |mr|
    mr.data.value = $redis.get 'key3'
  end

  run do |mr|
    "hey #{mr.data.value}"
  end
end

result = do_other_stuff.execute   #=> "hey baz"
```

The two operations can still be executed separately like before, but they can also be combined through Multi Redis:

```rb
MultiRedis.execute do_stuff, do_other_stuff
```

All redis calls get grouped into the same MULTI/EXEC:

```
One request:
- MULTI
- GET foo
- GETSET bar newvalue
- GET baz
- EXEC
```

The array of results is also returned by the `execute` call:

```rb
MultiRedis.execute do_stuff, do_other_stuff   #=> [ 'value 1 is foo, value 2 is bar', 'hey baz' ]
```

## Meta

* **Author:** Simon Oulevay (Alpha Hydrae)
* **License:** MIT (see [LICENSE.txt](https://raw.github.com/AlphaHydrae/multi_redis/master/LICENSE.txt))
