# frozen_string_literal: true

module RedmineCsat
  # Works out who should receive the survey for an issue.
  #
  # 1. A single active user directly related to the issue (author, assignee or
  #    watcher) who has the configured customer role. The author wins a tie.
  # 2. Otherwise, the first valid address in the configured issue custom field.
  class CustomerResolver
    Result = Struct.new(:email, :user, :source, keyword_init: true)

    def initialize(issue)
      @issue = issue
    end

    def call
      user = customer_user
      return Result.new(email: user.mail.strip, user: user, source: 'customer-role') if user&.mail.present?

      email = owner_email
      email ? Result.new(email: email, user: nil, source: 'owner-email') : nil
    end

    private

    attr_reader :issue

    def customer_user
      role_id = Settings.role_id
      return unless role_id

      candidates = [issue.author, issue.assigned_to].compact
      candidates.concat(issue.watcher_users.to_a) if issue.respond_to?(:watcher_users)
      eligible = candidates.uniq.select do |user|
        user.is_a?(User) && !user.is_a?(AnonymousUser) && user.active? &&
          user.roles_for_project(issue.project).any? { |role| role.id == role_id }
      end
      return eligible.first if eligible.one?

      eligible.include?(issue.author) ? issue.author : nil
    end

    # The field may hold several addresses separated by commas, semicolons or
    # whitespace; the first valid one is used.
    def owner_email
      field_id = Settings.owner_email_custom_field_id
      return unless field_id

      raw = issue.custom_values.detect { |value| value.custom_field_id == field_id }&.value.to_s
      raw.split(/[\s,;]+/).map(&:strip).find { |candidate| EmailNormalizer.call(candidate) }
    end
  end
end
