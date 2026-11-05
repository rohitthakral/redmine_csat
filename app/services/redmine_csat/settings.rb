# frozen_string_literal: true

module RedmineCsat
  # Typed access to the plugin settings.
  class Settings
    DEFAULT_PROMPT = 'How was your experience with us?'
    DEFAULT_SUBJECT = 'How was your experience? Issue #%{issue_id}'

    DEFAULTS = {
      'enabled' => '1',
      'customer_role_id' => '',
      'owner_email_custom_field_id' => '',
      'trigger_status_ids' => [],
      'cooldown_days' => '14',
      'minimum_issue_age_hours' => '0',
      'link_validity_days' => '60',
      'response_edit_window_hours' => '24',
      'auto_submit_vote' => '0',
      'rating_prompt' => DEFAULT_PROMPT,
      'poor_label' => 'Poor',
      'okay_label' => 'OK',
      'great_label' => 'Great',
      'allow_comment' => '1',
      'create_follow_up_on_poor' => '0',
      'follow_up_project_id' => '',
      'follow_up_tracker_id' => '',
      'follow_up_assignee_id' => '',
      'follow_up_author_id' => '',
      'follow_up_private' => '1',
      'mail_subject' => DEFAULT_SUBJECT,
      'from_address' => '',
      'deliver_async' => '0',
      'ip_hash_retention_days' => '90',
      'data_retention_days' => '0'
    }.freeze

    class << self
      def data
        DEFAULTS.merge(Setting.plugin_redmine_csat.presence || {})
      end

      def enabled? = truthy?(data['enabled'])
      def role_id = int(data['customer_role_id'])
      def owner_email_custom_field_id = int(data['owner_email_custom_field_id'])
      def trigger_status_ids = Array(data['trigger_status_ids']).filter_map { |v| int(v) }.uniq
      def cooldown_days = non_negative(data['cooldown_days'])
      def minimum_issue_age_hours = non_negative(data['minimum_issue_age_hours'])
      def link_validity_days = non_negative(data['link_validity_days'])
      def response_edit_window_hours = non_negative(data['response_edit_window_hours'])
      def auto_submit_vote? = truthy?(data['auto_submit_vote'])
      def allow_comment? = truthy?(data['allow_comment'])
      def create_follow_up_on_poor? = truthy?(data['create_follow_up_on_poor'])
      def follow_up_project_id = int(data['follow_up_project_id'])
      def follow_up_tracker_id = int(data['follow_up_tracker_id'])
      def follow_up_assignee_id = int(data['follow_up_assignee_id'])
      def follow_up_author_id = int(data['follow_up_author_id'])
      def follow_up_private? = truthy?(data['follow_up_private'])
      def deliver_async? = truthy?(data['deliver_async'])
      def ip_hash_retention_days = non_negative(data['ip_hash_retention_days'])
      def data_retention_days = non_negative(data['data_retention_days'])
      def prompt = data['rating_prompt'].presence || DEFAULT_PROMPT

      def labels
        {
          poor: data['poor_label'].presence || 'Poor',
          okay: data['okay_label'].presence || 'OK',
          great: data['great_label'].presence || 'Great'
        }
      end

      def from_address = data['from_address'].presence || Setting.mail_from

      def mail_subject(issue)
        format(data['mail_subject'].presence || DEFAULT_SUBJECT,
               issue_id: issue.id, issue_subject: issue.subject, project: issue.project.name)
      rescue KeyError, ArgumentError
        "How was your experience? Issue ##{issue.id}"
      end

      private

      def truthy?(value) = %w[1 true yes on].include?(value.to_s.downcase)
      def int(value) = value.to_i.positive? ? value.to_i : nil
      def non_negative(value) = [value.to_i, 0].max
    end
  end
end
