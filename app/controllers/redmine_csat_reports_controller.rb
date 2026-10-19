class RedmineCsatReportsController < ApplicationController
  before_action :find_project
  before_action :authorize
  def index
    scope = RedmineCsatResponse.where(project_id: @project.id)
    @responses = scope.includes(:issue, :request, :customer_user).order(responded_at: :desc).limit(200)
    @counts = scope.group(:rating).count
    @total_sent = RedmineCsatRequest.where(project_id: @project.id).count
    @total_responded = scope.count
    @response_rate = @total_sent.positive? ? (100.0 * @total_responded / @total_sent).round(1) : 0
    @csat = @total_responded.positive? ? (100.0 * scope.where(rating: 3).count / @total_responded).round(1) : 0
  end
  private
  def find_project = @project = Project.find(params[:project_id])
end
