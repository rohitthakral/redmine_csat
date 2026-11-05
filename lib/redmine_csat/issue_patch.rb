# frozen_string_literal: true

module RedmineCsat
  # Adds CSAT associations and the status-transition trigger to Issue.
  module IssuePatch
    extend ActiveSupport::Concern

    included do
      has_many :redmine_csat_requests, class_name: 'RedmineCsatRequest',
                                       dependent: :destroy
      has_many :redmine_csat_follow_up_responses, class_name: 'RedmineCsatResponse',
                                                  foreign_key: :follow_up_issue_id,
                                                  dependent: :nullify

      after_update :redmine_csat_track_status_change
      after_commit :redmine_csat_after_status_change, on: :update
      after_rollback { @redmine_csat_status_changed = false }
    end

    private

    # The issue may be saved more than once in a transaction, and after_commit
    # only sees the changes from the last save, so status changes are
    # remembered as they happen.
    def redmine_csat_track_status_change
      @redmine_csat_status_changed = true if saved_change_to_status_id?
    end

    def redmine_csat_after_status_change
      return unless @redmine_csat_status_changed

      @redmine_csat_status_changed = false
      return unless RedmineCsat::Settings.trigger_status_ids.include?(status_id)

      journal = current_journal if current_journal&.persisted?
      journal ||= journals.reorder(id: :desc).first
      RedmineCsat::SurveyDispatcher.new(self, journal: journal).call
    rescue StandardError => e
      Rails.logger.error("[redmine_csat] issue ##{id}: #{e.class}: #{e.message}")
    end
  end
end
