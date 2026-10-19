module RedmineCsat
  class FollowUpCreator
    def initialize(response) = @response = response
    def call
      return unless @response.rating == 1 && Settings.create_follow_up_on_poor?
      tracker = Tracker.find_by(id: Settings.follow_up_tracker_id) || @response.issue.tracker
      author = User.active.where(admin: true).first || @response.issue.author
      return unless author
      Issue.create!(project: @response.project, tracker: tracker, author: author,
        assigned_to_id: Settings.follow_up_assignee_id,
        subject: "CSAT follow-up: Issue ##{@response.issue_id} - #{@response.issue.subject}",
        description: "A customer selected Poor for issue ##{@response.issue_id}.\n\nComment: #{@response.comment.presence || '(none)'}")
    rescue StandardError => e
      Rails.logger.error("[redmine_csat] follow-up failed: #{e.class}: #{e.message}")
      nil
    end
  end
end
