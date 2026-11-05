# frozen_string_literal: true

require_relative '../test_helper'

class RedmineCsatSurveyDispatcherTest < ActiveSupport::TestCase
  include RedmineCsatTestHelper
  fixtures(*CSAT_FIXTURES)

  setup do
    configure_csat
    enable_csat
    ActionMailer::Base.deliveries.clear
  end

  test 'closing an issue sends one survey to the customer-role author' do
    close_issue(Issue.find(1))

    request = RedmineCsatRequest.find_by(issue_id: 1)
    assert request
    assert request.delivered?
    assert_equal User.find(2), request.customer_user
    assert_equal 1, ActionMailer::Base.deliveries.size

    mail = ActionMailer::Base.deliveries.last
    assert_equal ['jsmith@somenet.foo'], mail.to
    assert_equal 'auto-generated', mail['Auto-Submitted'].to_s
    assert_includes mail.text_part.body.to_s, '/csat/v/'
  end

  test 'survey links respect the host name and sub-path setting' do
    with_settings host_name: 'example.net/redmine', protocol: 'https' do
      close_issue(Issue.find(1))
    end
    assert_includes ActionMailer::Base.deliveries.last.text_part.body.to_s, 'https://example.net/redmine/csat/v/'
  end

  test 'closing the issue again does not send a second survey' do
    issue = Issue.find(1)
    close_issue(issue)
    issue.reload.update_columns(status_id: 1)
    close_issue(issue)

    assert_equal 1, RedmineCsatRequest.where(issue_id: 1).count
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test 'a failed delivery removes the request so the issue and email are not blocked' do
    RedmineCsatMailer.stubs(:survey).raises(RuntimeError, 'SMTP is down')
    result = RedmineCsat::SurveyDispatcher.new(Issue.find(1).tap { |i| i.status_id = 5 }).call
    assert_equal 'delivery_failed', result.reason
    refute RedmineCsatRequest.exists?(issue_id: 1)
    RedmineCsatMailer.unstub(:survey)

    configure_csat('cooldown_days' => '14')
    issue = Issue.find(1)
    issue.status_id = 5
    assert_kind_of RedmineCsatRequest, RedmineCsat::SurveyDispatcher.new(issue).call
  end

  test 'a stale undelivered request is replaced' do
    create_csat_request(delivered_at: nil, sent_at: 2.hours.ago)
    issue = Issue.find(1)
    issue.status_id = 5

    result = RedmineCsat::SurveyDispatcher.new(issue).call

    assert_kind_of RedmineCsatRequest, result
    assert_equal 1, RedmineCsatRequest.where(issue_id: 1).count
    assert result.reload.delivered?
  end

  test 'cooldown suppresses other issues for the same email' do
    configure_csat('cooldown_days' => '14')
    create_csat_request(issue: Issue.find(3), raw_token: 'other')
    issue = Issue.find(1)
    issue.status_id = 5

    assert_equal 'cooldown_active', RedmineCsat::SurveyDispatcher.new(issue).call.reason
  end

  test 'falls back to the owner-email custom field' do
    field = IssueCustomField.create!(name: 'owner-email', field_format: 'string', is_for_all: true,
                                     tracker_ids: Tracker.pluck(:id))
    configure_csat('customer_role_id' => '', 'owner_email_custom_field_id' => field.id.to_s)
    issue = Issue.find(1)
    issue.custom_field_values = { field.id.to_s => 'not-an-email; Owner@Example.com' }
    issue.save!
    issue.status_id = 5

    request = RedmineCsat::SurveyDispatcher.new(issue).call

    assert_kind_of RedmineCsatRequest, request
    assert_equal 'owner@example.com', request.recipient_email_normalized
    assert_nil request.customer_user
  end

  test 'nothing is sent when the project module is disabled' do
    Project.find(1).disable_module!(:redmine_csat)
    close_issue(Issue.find(1))
    refute RedmineCsatRequest.exists?(issue_id: 1)
  end
end
