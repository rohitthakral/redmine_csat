# frozen_string_literal: true

class RedmineCsatRequest < ActiveRecord::Base
  self.table_name = 'redmine_csat_requests'

  belongs_to :issue
  belongs_to :project
  belongs_to :journal, optional: true
  belongs_to :customer_user, class_name: 'User', optional: true
  belongs_to :agent_user, class_name: 'User', optional: true
  has_one :response, class_name: 'RedmineCsatResponse', foreign_key: :request_id,
                     dependent: :destroy, inverse_of: :request

  validates :recipient_email, :recipient_email_normalized, :token_digest, :sent_at, presence: true
  validates :token_digest, uniqueness: true
  validates :issue_id, uniqueness: true

  def self.digest_token(raw_token)
    Digest::SHA256.hexdigest(raw_token.to_s)
  end

  def self.find_by_raw_token(raw_token)
    find_by(token_digest: digest_token(raw_token))
  end

  def responded?
    responded_at.present? || response.present?
  end
end
