RSpec::Matchers.define :be_a_redis_future do

  match do |actual|
    actual.is_a? Redis::Future
  end
end
