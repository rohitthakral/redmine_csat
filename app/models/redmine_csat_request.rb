# frozen_string_literal: true

# One survey sent for one issue. The raw token only ever exists in the email;
# the database keeps its SHA-256 digest.
class RedmineCsatRequest < ActiveRecord::Base
  self.table_name = 'redmine_csat_requests'

  # A request whose email has not been confirmed as delivered after this long
  # is treated as failed: it no longer suppresses other surveys and can be
  # replaced the next time the issue reaches a trigger status.
  PENDING_GRACE = 1.hour

  belongs_to :issue
  belongs_to :project
  belongs_to :journal, optional: true
  belongs_to :customer_user, class_name: 'User', optional: true
  belongs_to :agent_user, class_name: 'User', optional: true
  has_one :csat_response, class_name: 'RedmineCsatResponse', foreign_key: :request_id,
                          dependent: :destroy, inverse_of: :csat_request

  validates :recipient_email, :recipient_email_normalized, :token_digest, :sent_at, presence: true
  validates :token_digest, uniqueness: true
  validates :issue_id, uniqueness: true

  scope :delivered, -> { where.not(delivered_at: nil) }
  scope :pending, -> { where(delivered_at: nil).where('sent_at >= ?', PENDING_GRACE.ago) }
  scope :stale_pending, -> { where(delivered_at: nil).where('sent_at < ?', PENDING_GRACE.ago) }
  # Requests that count towards the per-email cooldown.
  scope :suppressing, -> { delivered.or(pending) }

  def self.digest_token(raw_token)
    Digest::SHA256.hexdigest(raw_token.to_s)
  end

  def self.find_by_raw_token(raw_token)
    return nil if raw_token.blank?

    find_by(token_digest: digest_token(raw_token))
  end

  def delivered?
    delivered_at.present?
  end

  def stale_pending?
    !delivered? && sent_at < PENDING_GRACE.ago
  end

  def expired?
    days = RedmineCsat::Settings.link_validity_days
    days.positive? && sent_at < days.days.ago
  end

  def responded?
    responded_at.present? || csat_response.present?
  end
end
