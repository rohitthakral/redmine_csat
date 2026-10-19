# frozen_string_literal: true

require_relative 'lib/redmine_csat/hooks'
require_relative 'lib/redmine_csat/issue_patch'

Redmine::Plugin.register :redmine_csat do
  name 'Redmine CSAT'
  author 'Target Integration'
  description 'One-click CSAT surveys for Redmine issues with customer-role and owner-email recipient resolution.'
  version '0.1.0'
  requires_redmine version_or_higher: '6.1.2'

  settings default: {
    'enabled' => '1',
    'customer_role_id' => '',
    'owner_email_custom_field_id' => '',
    'trigger_status_ids' => [],
    'cooldown_days' => '14',
    'minimum_issue_age_hours' => '0',
    'rating_prompt' => 'How was your experience with us?',
    'poor_label' => 'Poor',
    'okay_label' => 'OK',
    'great_label' => 'Great',
    'allow_comment' => '1',
    'create_follow_up_on_poor' => '0',
    'follow_up_tracker_id' => '',
    'follow_up_assignee_id' => '',
    'mail_subject' => 'How was your experience? Issue #%{issue_id}',
    'from_address' => ''
  }, partial: 'settings/redmine_csat_settings'

  project_module :redmine_csat do
    permission :view_csat_reports, { redmine_csat_reports: [:index] }
  end

  menu :project_menu,
       :redmine_csat,
       { controller: 'redmine_csat_reports', action: 'index' },
       caption: :label_redmine_csat,
       after: :activity,
       param: :project_id,
       if: proc { |project| project.module_enabled?(:redmine_csat) }
end
