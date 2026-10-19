class RedmineCsatMailer < ActionMailer::Base
  helper :application
  default from: proc { RedmineCsat::Settings.from_address }
  def survey(request_id, raw_token)
    @request = RedmineCsatRequest.includes(:issue).find(request_id)
    @issue, @prompt, @labels = @request.issue, RedmineCsat::Settings.prompt, RedmineCsat::Settings.labels
    @vote_urls = RedmineCsatResponse::RATINGS.keys.index_with { |rating| redmine_csat_vote_url(raw_token, rating, host: Setting.host_name, protocol: Setting.protocol) }
    mail(to: @request.recipient_email, subject: RedmineCsat::Settings.mail_subject(@issue))
  end
end
