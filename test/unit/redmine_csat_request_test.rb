require_relative '../test_helper'
class RedmineCsatRequestTest < ActiveSupport::TestCase
  test 'token digest is deterministic and does not expose raw value' do
    digest = RedmineCsatRequest.digest_token('secret')
    assert_equal 64, digest.length
    assert_equal digest, RedmineCsatRequest.digest_token('secret')
    refute_equal 'secret', digest
  end
end
