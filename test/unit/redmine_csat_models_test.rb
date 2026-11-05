# frozen_string_literal: true

require_relative '../test_helper'

class RedmineCsatModelsTest < ActiveSupport::TestCase
  include RedmineCsatTestHelper
  fixtures(*CSAT_FIXTURES)

  setup { configure_csat }

  test 'token digest is deterministic and does not expose the raw value' do
    digest = RedmineCsatRequest.digest_token('secret')
    assert_equal 64, digest.length
    assert_equal digest, RedmineCsatRequest.digest_token('secret')
    refute_equal 'secret', digest
  end

  test 'blank tokens never match a request' do
    assert_nil RedmineCsatRequest.find_by_raw_token('')
  end

  test 'only one request per issue' do
    create_csat_request
    duplicate = RedmineCsatRequest.new(issue_id: 1, project_id: 1, recipient_email: 'a@b.cd',
                                       recipient_email_normalized: 'a@b.cd',
                                       token_digest: RedmineCsatRequest.digest_token('other'),
                                       sent_at: Time.current)
    refute duplicate.valid?
    assert duplicate.errors.of_kind?(:issue_id, :taken)
  end

  test 'undelivered requests stop suppressing after the grace period' do
    pending = create_csat_request(delivered_at: nil, sent_at: 10.minutes.ago)
    assert_includes RedmineCsatRequest.suppressing, pending
    refute pending.stale_pending?

    pending.update_columns(sent_at: 2.hours.ago)
    refute_includes RedmineCsatRequest.suppressing, pending
    assert pending.reload.stale_pending?
  end

  test 'links expire after the configured number of days' do
    request = create_csat_request(sent_at: 61.days.ago)
    assert request.expired?

    configure_csat('link_validity_days' => '0')
    refute request.expired?
  end

  test 'responses are editable only inside the edit window' do
    response = create_csat_response(create_csat_request)
    assert response.editable?

    response.update_columns(responded_at: 25.hours.ago)
    refute response.reload.editable?

    configure_csat('response_edit_window_hours' => '0')
    response.update_columns(responded_at: Time.current)
    refute response.reload.editable?
  end

  test 'deleting an issue removes its survey data' do
    request = create_csat_request
    create_csat_response(request)

    Issue.find(1).destroy

    refute RedmineCsatRequest.exists?(request.id)
    refute RedmineCsatResponse.exists?(request_id: request.id)
  end

  test 'deleting a follow-up issue clears the link on the response' do
    response = create_csat_response(create_csat_request, rating: RedmineCsatResponse::POOR,
                                                         follow_up_issue_id: 3)
    Issue.find(3).destroy
    assert_nil response.reload.follow_up_issue_id
  end

  test 'mail subject survives malformed templates' do
    issue = Issue.find(1)
    configure_csat('mail_subject' => '%{issue_id} is 100%')
    assert_equal "How was your experience? Issue ##{issue.id}", RedmineCsat::Settings.mail_subject(issue)

    configure_csat('mail_subject' => 'Issue %{issue_id} in %{project}')
    assert_equal "Issue #{issue.id} in #{issue.project.name}", RedmineCsat::Settings.mail_subject(issue)
  end

  test 'email normaliser' do
    assert_equal 'person@example.com', RedmineCsat::EmailNormalizer.call(' Person@Example.COM ')
    assert_nil RedmineCsat::EmailNormalizer.call('invalid')
    assert_nil RedmineCsat::EmailNormalizer.call("a@b.cd\nBcc: x@y.z")
  end

  test 'retention purge clears old IP hashes and old surveys' do
    configure_csat('ip_hash_retention_days' => '30', 'data_retention_days' => '365')
    recent = create_csat_response(create_csat_request, ip_hash: 'abc')
    old_request = create_csat_request(issue: Issue.find(2), raw_token: 'old', sent_at: 400.days.ago)
    create_csat_response(old_request, ip_hash: 'def', responded_at: 400.days.ago)

    result = RedmineCsat::RetentionPurger.new.call

    assert_equal 1, result[:ip_hashes_cleared]
    assert_equal 1, result[:requests_deleted]
    assert_equal 'abc', recent.reload.ip_hash
    refute RedmineCsatRequest.exists?(old_request.id)
  end
end
