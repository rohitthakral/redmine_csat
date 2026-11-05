# frozen_string_literal: true

# Project-level CSAT report (HTML and CSV).
#
# The period filter applies to the date the survey was sent, so the response
# rate and the score describe the same set of surveys. Only issues the
# current user can see are included.
class RedmineCsatReportsController < ApplicationController
  menu_item :redmine_csat

  before_action :find_project_by_project_id
  before_action :authorize

  def index
    load_filters
    requests = filtered_requests
    responses = RedmineCsatResponse.where(request_id: requests.select(:id))

    @total_sent = requests.count
    @total_responded = responses.count
    @counts = responses.group(:rating).count
    @response_rate = percentage(@total_responded, @total_sent)
    @csat = percentage(@counts[RedmineCsatResponse::GREAT].to_i, @total_responded)
    @follow_up_errors = responses.where.not(follow_up_error: [nil, '']).count

    ordered = responses.includes(:issue, :csat_request, :customer_user, :follow_up_issue)
                       .order(responded_at: :desc, id: :desc)

    respond_to do |format|
      format.html do
        @response_pages = Paginator.new(@total_responded, per_page_option, params['page'])
        @responses = ordered.limit(@response_pages.per_page).offset(@response_pages.offset).to_a
      end
      format.csv do
        send_data(responses_to_csv(ordered), type: 'text/csv; header=present',
                                             filename: "csat-#{@project.identifier}.csv")
      end
    end
  end

  private

  def load_filters
    @from = parse_date(params[:from])
    @to = parse_date(params[:to])
    @with_subprojects =
      if params.key?(:with_subprojects)
        params[:with_subprojects] == '1'
      else
        Setting.display_subprojects_issues?
      end
  end

  def filtered_requests
    project_ids = @with_subprojects ? @project.self_and_descendants.pluck(:id) : [@project.id]
    visible_issues = Issue.visible.where(project_id: project_ids).select(:id)
    scope = RedmineCsatRequest.delivered.where(issue_id: visible_issues)
    scope = scope.where('sent_at >= ?', @from.beginning_of_day) if @from
    scope = scope.where('sent_at <= ?', @to.end_of_day) if @to
    scope
  end

  def parse_date(value)
    Date.iso8601(value.to_s) if value.present?
  rescue ArgumentError
    nil
  end

  def percentage(part, total)
    total.positive? ? (100.0 * part / total).round(1) : 0
  end

  def responses_to_csv(responses)
    labels = RedmineCsat::Settings.labels
    Redmine::Export::CSV.generate(encoding: params[:encoding]) do |csv|
      csv << [l(:field_issue), l(:field_subject), l(:field_project), l(:field_csat_rating),
              l(:field_csat_customer), l(:field_mail), l(:field_csat_comment),
              l(:field_csat_responded_on), l(:field_updated_on), l(:field_csat_follow_up_issue)]
      responses.each do |response|
        csv << [response.issue_id, response.issue&.subject, response.issue&.project&.name,
                labels[response.rating_name.to_sym], response.customer_user&.name,
                response.csat_request&.recipient_email, response.comment,
                format_time(response.responded_at), format_time(response.updated_at),
                response.follow_up_issue_id]
      end
    end
  end
end
