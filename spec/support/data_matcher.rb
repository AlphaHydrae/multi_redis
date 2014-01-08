
RSpec::Matchers.define :have_data do |expected|

  match do |actual|

    expected_last_results = expected[:last_results] || []
    @last_results_match = actual.last_results == expected_last_results

    expected_pairs = expected.reject{ |k,v| k == :last_results }

    value_mismatches = expected_pairs.select{ |k,v| actual.data[k] != expected[k] }
    @pairs_match = value_mismatches.empty?

    method_mismatches = expected_pairs.select{ |k,v| actual.data[k] != expected[k] rescue true }
    @methods_match = method_mismatches.empty?

    @last_results_match && @pairs_match && @methods_match
  end

  failure_message_for_should do |actual|
    "expected that #{actual.inspect} would be multi_redis data containing #{expected}"
  end

  failure_message_for_should_not do |actual|
    "expected that #{actual.inspect} would not be multi_redis data containing #{expected}"
  end

  description do
    "be multi_redis data containing #{expected}"
  end
end
