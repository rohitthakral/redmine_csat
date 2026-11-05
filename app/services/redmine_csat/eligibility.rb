# frozen_string_literal: true

module RedmineCsat
  # Decides whether an issue should get a survey now, and for whom.
  class Eligibility
    Result = Struct.new(:eligible, :reason, :customer, keyword_init: true) do
      def eligible? = eligible
    end

    def initialize(issue)
      @issue = issue
    end

    def call
      return no('plugin_disabled') unless Settings.enabled?
      return no('project_module_disabled') unless @issue.project&.module_enabled?(:redmine_csat)
      return no('status_not_configured') unless Settings.trigger_status_ids.include?(@issue.status_id)
      return no('mail_deliveries_disabled') unless RedmineCsatMailer.perform_deliveries
      return no('csat_follow_up_issue') if RedmineCsatResponse.exists?(follow_up_issue_id: @issue.id)
      return no('request_already_exists') if existing_request_blocks?
      return no('issue_too_young') if too_young?

      customer = CustomerResolver.new(@issue).call
      return no('customer_not_found') unless customer

      email = EmailNormalizer.call(customer.email)
      return no('invalid_customer_email') unless email
      return no('cooldown_active') if cooldown_active?(email)

      Result.new(eligible: true, reason: 'eligible', customer: customer)
    end

    private

    # One survey per issue. A request whose email never went out (stale
    # pending) does not count and will be replaced.
    def existing_request_blocks?
      existing = RedmineCsatRequest.find_by(issue_id: @issue.id)
      existing.present? && !existing.stale_pending?
    end

    def too_young?
      hours = Settings.minimum_issue_age_hours
      hours.positive? && @issue.created_on > hours.hours.ago
    end

    def cooldown_active?(email)
      days = Settings.cooldown_days
      return false unless days.positive?

      RedmineCsatRequest.suppressing
                        .where(recipient_email_normalized: email)
                        .where('sent_at >= ?', days.days.ago)
                        .where.not(issue_id: @issue.id)
                        .exists?
    end

    def no(reason) = Result.new(eligible: false, reason: reason)
  end
end
