module RedmineCsat
  class Settings
    class << self
      def data = Setting.plugin_redmine_csat || {}
      def enabled? = truthy?(data['enabled'])
      def role_id = int(data['customer_role_id'])
      def owner_email_custom_field_id = int(data['owner_email_custom_field_id'])
      def trigger_status_ids = Array(data['trigger_status_ids']).filter_map { |v| int(v) }.uniq
      def cooldown_days = [data['cooldown_days'].to_i, 0].max
      def minimum_issue_age_hours = [data['minimum_issue_age_hours'].to_i, 0].max
      def allow_comment? = truthy?(data['allow_comment'])
      def create_follow_up_on_poor? = truthy?(data['create_follow_up_on_poor'])
      def follow_up_tracker_id = int(data['follow_up_tracker_id'])
      def follow_up_assignee_id = int(data['follow_up_assignee_id'])
      def prompt = data['rating_prompt'].presence || 'How was your experience with us?'
      def labels = { poor: data['poor_label'].presence || 'Poor', okay: data['okay_label'].presence || 'OK', great: data['great_label'].presence || 'Great' }
      def from_address = data['from_address'].presence || Setting.mail_from
      def mail_subject(issue)
        (data['mail_subject'].presence || 'How was your experience? Issue #%{issue_id}') % { issue_id: issue.id, issue_subject: issue.subject, project: issue.project.name }
      rescue KeyError
        "How was your experience? Issue ##{issue.id}"
      end
      private
      def truthy?(value) = %w[1 true yes on].include?(value.to_s.downcase)
      def int(value) = value.to_i.positive? ? value.to_i : nil
    end
  end
end
