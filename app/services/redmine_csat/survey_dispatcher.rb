# frozen_string_literal: true

require 'securerandom'

module RedmineCsat
  # Creates the survey request for an issue and sends the email.
  #
  # Returns the RedmineCsatRequest on success, or an Eligibility::Result
  # explaining why nothing was sent.
  class SurveyDispatcher
    def initialize(issue, journal: nil)
      @issue = issue
      @journal = journal
    end

    def call
      eligibility = Eligibility.new(@issue).call
      return eligibility unless eligibility.eligible?

      raw_token = SecureRandom.urlsafe_base64(32)
      request = create_request(eligibility.customer, raw_token)
      deliver(request, raw_token)
    rescue ActiveRecord::RecordNotUnique
      skipped('request_already_exists')
    rescue ActiveRecord::RecordInvalid => e
      raise unless e.record.errors.of_kind?(:issue_id, :taken)

      skipped('request_already_exists')
    end

    private

    def create_request(customer, raw_token)
      RedmineCsatRequest.transaction do
        RedmineCsatRequest.stale_pending.where(issue_id: @issue.id).destroy_all
        RedmineCsatRequest.create!(
          issue: @issue, project: @issue.project, journal: @journal,
          customer_user: customer.user, agent_user: agent_user,
          recipient_email: customer.email,
          recipient_email_normalized: EmailNormalizer.call(customer.email),
          token_digest: RedmineCsatRequest.digest_token(raw_token),
          sent_at: Time.current
        )
      end
    end

    def agent_user
      user = @journal&.user || @issue.assigned_to
      user.is_a?(User) ? user : nil
    end

    # The mailer marks the request as delivered once the email has actually
    # been handed to the delivery method. If sending fails synchronously the
    # request is removed, so the issue and the email address are not blocked.
    def deliver(request, raw_token)
      message = RedmineCsatMailer.survey(request.id, raw_token)
      Settings.deliver_async? ? message.deliver_later : message.deliver_now
      request
    rescue StandardError => e
      Rails.logger.error("[redmine_csat] survey email for issue ##{@issue.id} failed: #{e.class}: #{e.message}")
      request.destroy
      skipped('delivery_failed')
    end

    def skipped(reason) = Eligibility::Result.new(eligible: false, reason: reason)
  end
end
