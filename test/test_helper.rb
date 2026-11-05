# frozen_string_literal: true

require File.expand_path('../../../test/test_helper', __dir__)

module RedmineCsatTestHelper
  CSAT_FIXTURES = %i[
    projects users email_addresses user_preferences roles members member_roles
    issues issue_statuses trackers projects_trackers enabled_modules enumerations
    workflows journals journal_details custom_fields custom_values
    custom_fields_projects custom_fields_trackers
  ].freeze

  # jsmith (user 2) is a Manager (role 1) in project 1 and the author of issue 1.
  def configure_csat(overrides = {})
    Setting.plugin_redmine_csat = RedmineCsat::Settings::DEFAULTS.merge(
      'customer_role_id' => '1',
      'trigger_status_ids' => ['5'],
      'cooldown_days' => '0'
    ).merge(overrides.stringify_keys)
  end

  def enable_csat(project = Project.find(1))
    project.enable_module!(:redmine_csat)
  end

  def create_csat_request(issue: Issue.find(1), raw_token: 'secret-token', **attrs)
    RedmineCsatRequest.create!({
      issue: issue, project: issue.project, customer_user: issue.author,
      recipient_email: 'jsmith@somenet.foo', recipient_email_normalized: 'jsmith@somenet.foo',
      token_digest: RedmineCsatRequest.digest_token(raw_token),
      sent_at: Time.current, delivered_at: Time.current
    }.merge(attrs))
  end

  def create_csat_response(csat_request, rating: RedmineCsatResponse::GREAT, **attrs)
    RedmineCsatResponse.create!({
      csat_request: csat_request, issue: csat_request.issue, project: csat_request.project,
      rating: rating, responded_at: Time.current
    }.merge(attrs))
  end

  def close_issue(issue, user: User.find(2))
    issue.reload
    issue.init_journal(user)
    issue.status_id = 5
    issue.save!
  end
end
