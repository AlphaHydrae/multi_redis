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

`redis-rb` allows you to run both in the same command pipeline:

```rb
results = $redis.pipelined do
  $redis.get 'key1'
  $redis.get 'key2'
end

results[0]   #=> "foo"
results[1]   #=> "bar"
```

But it would be hard to refactor the two methods to use a pipeline while still keeping them separate.

Multi Redis provides a pattern to structure this code so that your separate redis calls may be executed together in one request when needed.

```rb
$redis = Redis.new
$redis.set 'key1', 'foo'
$redis.set 'key2', 'bar'

# Create a redis operation, i.e. an operation that performs redis calls, for the first method.
do_stuff = MultiRedis::Operation.new do

  # Pipelined blocks will be run in a command pipeline.
  # All redis commands will return futures inside this block, so you can't use the values immediately.
  pipelined do |mr|
    $redis.get 'key1'
  end

  # This run block will be executed after the pipelined block is completed and all futures have been resolved.
  # The #last_results method of the Multi Redis context will return the results of all redis calls in the pipelined block.
  run do |mr|
    mr.last_results[0]   # => "foo"
  end
end

# The return value of the operation is that of the last block.
result = do_stuff.execute   #=> "foo"

# Create the redis operation for the other method.
do_other_stuff = MultiRedis::Operation.new do

  multi do |mr|
    $redis.get 'key2'
  end

  run do |mr|
    mr.last_results[0]   #=> "bar"
  end
end

result = do_other_stuff.execute   #=> "bar"
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
