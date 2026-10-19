require 'securerandom'
module RedmineCsat
  class SurveyDispatcher
    def initialize(issue, journal: nil) = (@issue, @journal = issue, journal)
    def call
      eligibility = Eligibility.new(@issue).call
      return eligibility unless eligibility.eligible?
      customer = eligibility.customer
      raw_token = SecureRandom.urlsafe_base64(32)
      request = RedmineCsatRequest.create!(issue: @issue, project: @issue.project, journal: @journal,
        customer_user: customer.user, agent_user: @journal&.user || @issue.assigned_to,
        recipient_email: customer.email, recipient_email_normalized: EmailNormalizer.call(customer.email),
        token_digest: RedmineCsatRequest.digest_token(raw_token), sent_at: Time.current)
      RedmineCsatMailer.survey(request.id, raw_token).deliver_now
      request
    rescue ActiveRecord::RecordNotUnique
      Eligibility::Result.new(eligible: false, reason: 'request_already_exists')
    end
  end
end
