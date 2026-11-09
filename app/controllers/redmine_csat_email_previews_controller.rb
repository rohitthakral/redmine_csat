# frozen_string_literal: true

# Lets administrators preview the survey email, or send it to themselves,
# straight from the plugin settings page. The buttons submit the settings form
# here, so unsaved changes are shown without being saved.
class RedmineCsatEmailPreviewsController < ApplicationController
  before_action :require_admin

  # POST /csat/admin/email_preview
  def show
    RedmineCsat::Settings.with_overrides(email_overrides) do
      email = RedmineCsat::SurveyEmail.sample(vote_urls: sample_vote_urls, customer_name: User.current.name)
      @subject = email.subject
      @html = email.html
      @text = email.text
      @warnings = email.warnings
      @custom_html = email.custom_html?
      @custom_text = email.custom_text?
      @from = RedmineCsat::Settings.from_address
    end
  end

  # POST /csat/admin/email_test
  def deliver
    if User.current.mail.blank?
      @error = l(:text_csat_test_no_email)
    else
      RedmineCsat::Settings.with_overrides(email_overrides) do
        RedmineCsatMailer.test_survey(User.current).deliver_now
      end
      @recipient = User.current.mail
    end
  rescue StandardError => e
    Rails.logger.error("[redmine_csat] test email failed: #{e.class}: #{e.message}")
    @error = l(:text_csat_test_failed, message: e.message)
  end

  private

  def email_overrides
    settings = params[:settings]
    return {} unless settings.respond_to?(:permit)

    settings.permit(*RedmineCsat::Settings::EMAIL_KEYS).to_h
  end

  def sample_vote_urls
    RedmineCsatResponse::RATINGS.keys.index_with { |rating| '#' + rating }
  end
end
