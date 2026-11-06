# frozen_string_literal: true

module RedmineCsat
  # Typed access to the plugin settings.
  class Settings
    DEFAULT_PROMPT = 'How was your experience with us?'
    DEFAULT_SUBJECT = 'How did we do? Request #{{issue_id}}'
    DEFAULT_BRAND_COLOR = '#2f6fb5'
    CUSTOM_TEMPLATE_LIMIT = 100_000

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
      'email_company_name' => '',
      'email_logo_url' => '',
      'email_brand_color' => DEFAULT_BRAND_COLOR,
      'email_show_issue_details' => '1',
      'email_intro' => '',
      'email_footer' => '',
      'email_custom_html' => '',
      'email_custom_text' => '',
      'deliver_async' => '0',
      'ip_hash_retention_days' => '90',
      'data_retention_days' => '0'
    }.freeze

    # Settings keys that affect the survey email, used by the email preview.
    EMAIL_KEYS = %w[
      rating_prompt poor_label okay_label great_label allow_comment mail_subject from_address
      link_validity_days email_company_name email_logo_url email_brand_color
      email_show_issue_details email_intro email_footer email_custom_html email_custom_text
    ].freeze

    class << self
      def data
        base = DEFAULTS.merge((Setting.plugin_redmine_csat.presence || {}).to_h.stringify_keys)
        overrides = Thread.current[:redmine_csat_settings_overrides]
        overrides ? base.merge(overrides) : base
      end

      # Temporarily replaces some settings for the current thread. Used to
      # preview or test-send the email with values that are not saved yet.
      def with_overrides(overrides)
        previous = Thread.current[:redmine_csat_settings_overrides]
        Thread.current[:redmine_csat_settings_overrides] = overrides.to_h.stringify_keys
        yield
      ensure
        Thread.current[:redmine_csat_settings_overrides] = previous
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

      def mail_subject_template = data['mail_subject'].presence || DEFAULT_SUBJECT
      def email_company_name = data['email_company_name'].to_s.strip.presence
      def email_show_issue_details? = truthy?(data['email_show_issue_details'])
      def email_intro = data['email_intro'].to_s.strip.presence
      def email_footer = data['email_footer'].to_s.strip.presence

      def email_logo_url
        url = data['email_logo_url'].to_s.strip
        url.match?(%r{\Ahttps?://[^\s"'<>]+\z}i) ? url : nil
      end

      def email_brand_color
        color = data['email_brand_color'].to_s.strip
        color.match?(/\A#\h{6}\z/) ? color : DEFAULT_BRAND_COLOR
      end

      def email_custom_html = custom_template(data['email_custom_html'])
      def email_custom_text = custom_template(data['email_custom_text'])

      private

      def truthy?(value) = %w[1 true yes on].include?(value.to_s.downcase)
      def int(value) = value.to_i.positive? ? value.to_i : nil
      def non_negative(value) = [value.to_i, 0].max

      def custom_template(value)
        value = value.to_s.strip
        value.presence if value.length <= CUSTOM_TEMPLATE_LIMIT
      end
    end
  end
end
