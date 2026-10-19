module RedmineCsat
  class Eligibility
    Result = Struct.new(:eligible, :reason, :customer, keyword_init: true) { def eligible? = eligible }
    def initialize(issue) = @issue = issue
    def call
      return no('plugin_disabled') unless Settings.enabled?
      return no('project_module_disabled') unless @issue.project.module_enabled?(:redmine_csat)
      return no('status_not_configured') unless Settings.trigger_status_ids.include?(@issue.status_id)
      return no('request_already_exists') if RedmineCsatRequest.exists?(issue_id: @issue.id)
      return no('issue_too_young') if Settings.minimum_issue_age_hours.positive? && @issue.created_on > Settings.minimum_issue_age_hours.hours.ago
      customer = CustomerResolver.new(@issue).call
      return no('customer_not_found') unless customer
      email = EmailNormalizer.call(customer.email)
      return no('invalid_customer_email') unless email
      if Settings.cooldown_days.positive? && RedmineCsatRequest.where(recipient_email_normalized: email).where('sent_at >= ?', Settings.cooldown_days.days.ago).exists?
        return no('cooldown_active')
      end
      Result.new(eligible: true, reason: 'eligible', customer: customer)
    end
    private
    def no(reason) = Result.new(eligible: false, reason: reason)
  end
end
