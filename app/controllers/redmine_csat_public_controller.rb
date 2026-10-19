class RedmineCsatPublicController < ApplicationController
  skip_before_action :check_if_login_required
  before_action :load_request
  def vote
    rating = RedmineCsatResponse::RATINGS[params[:rating]]
    return render_404 unless rating
    @response = record_first_response(rating)
    @allow_comment = RedmineCsat::Settings.allow_comment?
  rescue ActiveRecord::RecordNotUnique
    @response = @request.reload.response
    @allow_comment = RedmineCsat::Settings.allow_comment?
  end
  def comment
    return render_404 unless RedmineCsat::Settings.allow_comment? && @request.response
    @request.response.update!(comment: params[:comment].to_s.strip.first(10_000))
    RedmineCsat::FollowUpCreator.new(@request.response).call
    redirect_to redmine_csat_vote_path(params[:token], @request.response.rating_name), notice: l(:notice_csat_comment_saved)
  end
  private
  def load_request
    @request = RedmineCsatRequest.find_by_raw_token(params[:token])
    render_404 unless @request
  end
  def record_first_response(rating)
    return @request.response if @request.response
    response = nil
    RedmineCsatRequest.transaction do
      @request.lock!
      response = @request.response || RedmineCsatResponse.create!(request: @request, issue: @request.issue,
        project: @request.project, customer_user: @request.customer_user, agent_user: @request.agent_user,
        rating: rating, responded_at: Time.current,
        ip_hash: OpenSSL::HMAC.hexdigest('SHA256', Rails.application.secret_key_base.to_s, request.remote_ip.to_s))
      @request.update!(responded_at: response.responded_at)
    end
    RedmineCsat::FollowUpCreator.new(response).call
    response
  end
end
