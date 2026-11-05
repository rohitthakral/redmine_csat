# frozen_string_literal: true

# The customer's answer to a survey. `responded_at` is the time of the first
# answer; the rating and comment can be changed during the edit window.
class RedmineCsatResponse < ActiveRecord::Base
  self.table_name = 'redmine_csat_responses'

  POOR = 1
  OKAY = 2
  GREAT = 3
  RATINGS = { 'poor' => POOR, 'okay' => OKAY, 'great' => GREAT }.freeze
  RATING_NAMES = RATINGS.invert.freeze
  COMMENT_LIMIT = 10_000

  belongs_to :csat_request, class_name: 'RedmineCsatRequest', foreign_key: :request_id,
                            inverse_of: :csat_response
  belongs_to :issue
  belongs_to :project
  belongs_to :customer_user, class_name: 'User', optional: true
  belongs_to :agent_user, class_name: 'User', optional: true
  belongs_to :follow_up_issue, class_name: 'Issue', optional: true

  validates :request_id, uniqueness: true
  validates :rating, inclusion: { in: RATINGS.values }
  validates :responded_at, presence: true
  validates :comment, length: { maximum: COMMENT_LIMIT }

  def rating_name
    RATING_NAMES[rating]
  end

  def editable?
    hours = RedmineCsat::Settings.response_edit_window_hours
    hours.positive? && responded_at > hours.hours.ago
  end

  def editable_until
    responded_at + RedmineCsat::Settings.response_edit_window_hours.hours
  end
end
