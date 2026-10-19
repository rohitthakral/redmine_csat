# frozen_string_literal: true

class RedmineCsatResponse < ActiveRecord::Base
  self.table_name = 'redmine_csat_responses'

  RATINGS = { 'poor' => 1, 'okay' => 2, 'great' => 3 }.freeze
  RATING_NAMES = RATINGS.invert.freeze

  belongs_to :request, class_name: 'RedmineCsatRequest', inverse_of: :response
  belongs_to :issue
  belongs_to :project
  belongs_to :customer_user, class_name: 'User', optional: true
  belongs_to :agent_user, class_name: 'User', optional: true

  validates :request_id, uniqueness: true
  validates :rating, inclusion: { in: RATINGS.values }
  validates :responded_at, presence: true

  def rating_name
    RATING_NAMES[rating]
  end
end
