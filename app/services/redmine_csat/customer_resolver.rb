module RedmineCsat
  class CustomerResolver
    Result = Struct.new(:email, :user, :source, keyword_init: true)
    def initialize(issue) = @issue = issue
    def call
      user = customer_user
      return Result.new(email: user.mail.strip, user: user, source: 'customer-role') if user&.mail.present?
      email = owner_email
      email.present? ? Result.new(email: email.strip, user: nil, source: 'owner-email') : nil
    end
    private
    attr_reader :issue
    def customer_user
      role_id = Settings.role_id
      return unless role_id
      candidates = [issue.author, issue.assigned_to].compact
      candidates.concat(issue.watcher_users.to_a) if issue.respond_to?(:watcher_users)
      eligible = candidates.uniq.select { |u| u.is_a?(User) && u.active? && u.roles_for_project(issue.project).any? { |r| r.id == role_id } }
      return eligible.first if eligible.one?
      eligible.include?(issue.author) ? issue.author : nil
    end
    def owner_email
      id = Settings.owner_email_custom_field_id
      id && issue.custom_values.detect { |v| v.custom_field_id == id }&.value.to_s
    end
  end
end
