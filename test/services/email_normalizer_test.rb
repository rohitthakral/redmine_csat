require_relative '../test_helper'
class RedmineCsatEmailNormalizerTest < ActiveSupport::TestCase
  test('normalises email') { assert_equal 'person@example.com', RedmineCsat::EmailNormalizer.call(' Person@Example.COM ') }
  test('rejects malformed email') { assert_nil RedmineCsat::EmailNormalizer.call('invalid') }
end
