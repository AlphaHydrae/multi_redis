
module RedisSpecHelper

  def key name
    "multi_redis:test:#{name}"
  end
end
