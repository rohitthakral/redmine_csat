# frozen_string_literal: true

# Sends the survey email. Survey recipients are not always Redmine users, so
# this does not inherit from Redmine's Mailer (which requires a User), but it
# reuses Redmine's URL options so sub-path installs work.
#
# The content comes from RedmineCsat::SurveyEmail, which applies the email
# settings and any custom templates.
class RedmineCsatMailer < ActionMailer::Base
  include Redmine::I18n

  default from: -> { RedmineCsat::Settings.from_address }

  after_deliver :mark_request_delivered

  def self.default_url_options(*)
    ::Mailer.default_url_options
  end

  def survey(request_id, raw_token)
    @csat_request = RedmineCsatRequest.includes(:issue, :customer_user).find_by(id: request_id)
    return unless @csat_request&.issue

    issue = @csat_request.issue
    headers['X-Redmine-Issue-Id'] = issue.id.to_s

    ::I18n.with_locale(locale_for(@csat_request.customer_user&.language)) do
      email = RedmineCsat::SurveyEmail.for_request(
        @csat_request,
        vote_urls: vote_urls(raw_token),
        # Only Redmine users can open the issue, so others get no link.
        issue_url: (issue_url(issue) if @csat_request.customer_user)
      )
      deliver_survey_email(email, to: @csat_request.recipient_email)
    end
  end

  # Sends an example survey to an administrator. The rating links in it do
  # not belong to a real survey and lead to a "not found" page.
  def test_survey(user)
    ::I18n.with_locale(locale_for(user.language)) do
      email = RedmineCsat::SurveyEmail.sample(vote_urls: vote_urls('test'), customer_name: user.name)
      deliver_survey_email(email, to: user.mail, subject_prefix: "[#{::I18n.t(:label_csat_test)}] ")
    end
  end

  private

  def vote_urls(token)
    RedmineCsatResponse::RATINGS.keys.index_with { |rating| redmine_csat_vote_url(token: token, rating: rating) }
  end

  def deliver_survey_email(email, to:, subject_prefix: '')
    headers['Auto-Submitted'] = 'auto-generated'
    headers['X-Auto-Response-Suppress'] = 'All'
    html = email.html
    text = email.text

    mail(to: to, subject: subject_prefix + email.subject) do |format|
      format.text { render plain: text }
      format.html { render html: html.html_safe } # rubocop:disable Rails/OutputSafety
    end
  end

  def locale_for(language)
    candidates = [language, Setting.default_language, 'en']
    candidates.map(&:presence).compact.map(&:to_sym).find { |locale| ::I18n.available_locales.include?(locale) } || :en
  end

  def mark_request_delivered
    return unless @csat_request

    @csat_request.update_column(:delivered_at, Time.current) if RedmineCsatRequest.exists?(@csat_request.id)
  end
end
