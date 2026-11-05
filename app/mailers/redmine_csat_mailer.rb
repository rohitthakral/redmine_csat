# frozen_string_literal: true

# Sends the survey email. Survey recipients are not always Redmine users, so
# this does not inherit from Redmine's Mailer (which requires a User), but it
# reuses Redmine's URL options so sub-path installs work.
class RedmineCsatMailer < ActionMailer::Base
  include Redmine::I18n

  helper Redmine::I18n

  default from: -> { RedmineCsat::Settings.from_address }

  after_deliver :mark_request_delivered

  def self.default_url_options(*)
    ::Mailer.default_url_options
  end

  def survey(request_id, raw_token)
    @csat_request = RedmineCsatRequest.includes(:issue, :customer_user).find_by(id: request_id)
    return unless @csat_request&.issue

    @issue = @csat_request.issue
    @prompt = RedmineCsat::Settings.prompt
    @labels = RedmineCsat::Settings.labels
    @vote_urls = RedmineCsatResponse::RATINGS.keys.index_with do |rating|
      redmine_csat_vote_url(token: raw_token, rating: rating)
    end

    headers['Auto-Submitted'] = 'auto-generated'
    headers['X-Auto-Response-Suppress'] = 'All'
    headers['X-Redmine-Issue-Id'] = @issue.id.to_s

    ::I18n.with_locale(recipient_locale) do
      mail(to: @csat_request.recipient_email, subject: RedmineCsat::Settings.mail_subject(@issue))
    end
  end

  private

  def recipient_locale
    candidates = [@csat_request.customer_user&.language, Setting.default_language, 'en']
    candidates.map(&:presence).compact.map(&:to_sym).find { |locale| ::I18n.available_locales.include?(locale) } || :en
  end

  def mark_request_delivered
    return unless @csat_request

    @csat_request.update_column(:delivered_at, Time.current) if RedmineCsatRequest.exists?(@csat_request.id)
  end
end
