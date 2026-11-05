# frozen_string_literal: true

# Public survey pages, reached through the tokenised links in the email.
#
# GET requests never change data: email security scanners open every link in
# a message, so the rating is only recorded when the customer submits the form.
class RedmineCsatPublicController < ApplicationController
  skip_before_action :check_if_login_required

  before_action :load_csat_request
  before_action :ensure_available

  # GET /csat/v/:token/:rating - the link in the email.
  def confirm
    if @csat_response && !answer_editable?
      redirect_to redmine_csat_show_path(token: params[:token])
      return
    end

    @selected_rating = params[:rating]
    @auto_submit = @csat_response.nil? && RedmineCsat::Settings.auto_submit_vote?
    render_form
  end

  # GET /csat/v/:token - current answer, editable during the edit window.
  def show
    @selected_rating = @csat_response&.rating_name
    render_form
  end

  # POST /csat/v/:token
  def submit
    rating = RedmineCsatResponse::RATINGS[params[:rating].to_s]
    result = RedmineCsat::ResponseRecorder.new(
      @csat_request, rating: rating, comment: submitted_comment, remote_ip: request.remote_ip
    ).call

    case result.status
    when :created, :updated, :unchanged
      flash[:notice] = l(:notice_csat_saved)
    when :locked
      flash[:error] = l(:error_csat_locked)
    else
      flash[:error] = l(:error_csat_choose_rating)
    end
    redirect_to redmine_csat_show_path(token: params[:token])
  end

  private

  def load_csat_request
    @csat_request = RedmineCsatRequest.find_by_raw_token(params[:token])
    return render_404 unless @csat_request&.issue

    @csat_response = @csat_request.csat_response
  end

  # Disabled plugin or module: the link no longer works at all. Expired link:
  # an existing answer is still shown read-only, but nothing can be recorded.
  def ensure_available
    unless RedmineCsat::Settings.enabled? && @csat_request.issue.project&.module_enabled?(:redmine_csat)
      return render_unavailable(:text_csat_survey_closed, 404)
    end
    return unless @csat_request.expired?
    return if @csat_response && action_name != 'submit'

    render_unavailable(:text_csat_link_expired, 410)
  end

  def render_form
    @allow_comment = RedmineCsat::Settings.allow_comment?
    @editable = answer_editable?
    @labels = RedmineCsat::Settings.labels
    @prompt = RedmineCsat::Settings.prompt
    render :form
  end

  def answer_editable?
    return false if @csat_request.expired?

    @csat_response.nil? || @csat_response.editable?
  end

  def render_unavailable(message_key, status)
    @message = l(message_key)
    render :unavailable, status: status
  end

  def submitted_comment
    return nil unless RedmineCsat::Settings.allow_comment?
    return nil unless params[:comment].is_a?(String)

    params[:comment].strip.first(RedmineCsatResponse::COMMENT_LIMIT)
  end
end
