# Multi Redis

**Pattern to execute separate [redis-rb](https://github.com/redis/redis-rb) operations in the same command pipeline or multi/exec.**

[![Gem Version](https://badge.fury.io/rb/multi_redis.png)](http://badge.fury.io/rb/multi_redis)
[![Dependency Status](https://gemnasium.com/AlphaHydrae/multi_redis.png)](https://gemnasium.com/AlphaHydrae/multi_redis)
[![Build Status](https://secure.travis-ci.org/AlphaHydrae/multi_redis.png)](http://travis-ci.org/AlphaHydrae/multi_redis)
[![Coverage Status](https://coveralls.io/repos/AlphaHydrae/multi_redis/badge.png?branch=master)](https://coveralls.io/r/AlphaHydrae/multi_redis?branch=master)

## Installation

Put this in your Gemfile:

```rb
gem 'multi_redis', '~> 0.3.0'
```

Then run `bundle install`.

## Usage

Assume you have two separate methods that call redis:

```rb
$redis = Redis.new
$redis.set 'key1', 'foo'
$redis.set 'key2', 'bar'

class MyRedisClass

  def do_stuff
    $redis.get 'key1'
  end

  def do_other_stuff
    $redis.get 'key2'
  end
end

o = MyRedisClass.new
o.do_stuff         #=> "foo"
o.do_other_stuff   #=> "bar"
```

This works, but the redis client executes two separate requests to the server, and waits for the result of the first one to start the second one:

```
Request 1:
- GET key1

Request 2:
- GET key2
```

The `redis-rb` gem allows you to run both calls in the same command pipeline:

```rb
results = $redis.pipelined do
  $redis.get 'key1'
  $redis.get 'key2'
end

results[0]   #=> "foo"
results[1]   #=> "bar"
```

There is only one request now, but the two `$redis.get` calls are no longer in separate methods.
To keep them separate, you would have to write your methods so that they could be called in a pipeline.
But in a pipeline redis calls return futures, not values, because the calls have not been executed yet.

Multi Redis provides a pattern to more easily handle these futures.
It allows you to structure your code so that your separate redis calls may be executed together in one request when needed.

```rb
$redis = Redis.new
$redis.set 'key1', 'foo'
$redis.set 'key2', 'bar'

MultiRedis.redis = $redis   # Give Multi Redis a redis-rb client to use.

# Create a redis operation, i.e. an operation that performs redis calls, equivalent to the first method.
do_stuff = MultiRedis::Operation.new do
  pipelined{ |mr| mr.redis.get 'key1' }   # Run your redis command in a pipelined block. It will return a future.
  run{ |mr| mr.last_replies[0] }        # Access the result in a run block. The future has been resolved.
end

# Executing the operation will run all blocks in order and return the result of the last block.
do_stuff.execute   #=> "foo"

# Create another redis operation for the other method.
do_other_stuff = MultiRedis::Operation.new do
  pipelined{ |mr| mr.redis.get 'key2' }
  run{ |mr| mr.last_replies[0] }
end

do_other_stuff.execute   #=> "bar"
```

The two operations can still be executed separately like before, but they can also be combined through Multi Redis:

```rb
MultiRedis.execute do_stuff, do_other_stuff
```

Both redis calls get grouped into the same command pipeline:

```
One request:
- GET foo
- GET bar
```

The array of results is returned by the `execute` call:

```rb
MultiRedis.execute do_stuff, do_other_stuff   #=> [ "foo", "bar" ]
```

## Meta

* **Author:** Simon Oulevay (Alpha Hydrae)
* **License:** MIT (see [LICENSE.txt](https://raw.github.com/AlphaHydrae/multi_redis/master/LICENSE.txt))
