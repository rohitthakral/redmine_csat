module RedmineCsat
  module IssuePatch
    extend ActiveSupport::Concern
    included { after_commit :redmine_csat_after_status_change, on: :update }
    private
    def redmine_csat_after_status_change
      return unless previous_changes['status_id'].present?
      return unless RedmineCsat::Settings.trigger_status_ids.include?(status_id)
      RedmineCsat::SurveyDispatcher.new(self, journal: journals.order(id: :desc).first).call
    rescue StandardError => e
      Rails.logger.error("[redmine_csat] issue ##{id}: #{e.class}: #{e.message}")
    end
  end
end
Rails.application.config.to_prepare { Issue.include(RedmineCsat::IssuePatch) unless Issue < RedmineCsat::IssuePatch }
