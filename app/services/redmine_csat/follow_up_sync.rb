# frozen_string_literal: true

module RedmineCsat
  # Creates at most one follow-up issue per response when the customer picks
  # Poor, and records later rating or comment changes as notes on it.
  #
  # Failures never reach the customer: they are logged and stored on the
  # response (`follow_up_error`) so they show up in the project report.
  class FollowUpSync
    def initialize(response, previous: nil)
      @response = response
      @previous = previous
    end

    def call
      return unless @response

      if follow_up_issue
        add_change_note
      elsif should_create?
        create_follow_up
      end
    rescue StandardError => e
      record_error("#{e.class}: #{e.message}")
    end

    private

    attr_reader :response

    def follow_up_issue
      @follow_up_issue ||= response.follow_up_issue
    end

    def original_issue
      response.issue
    end

    # Create on the first Poor answer, on a change to Poor, or to retry an
    # earlier failed attempt. A follow-up deleted by staff is not recreated
    # just because the customer edits their comment.
    def should_create?
      return false unless Settings.create_follow_up_on_poor?
      return false unless response.rating == RedmineCsatResponse::POOR
      return false if response.follow_up_issue_id.present?

      @previous.nil? || @previous[:rating] != RedmineCsatResponse::POOR || response.follow_up_error.present?
    end

    def create_follow_up
      project = target_project
      tracker = pick_tracker(project)
      return record_error('No tracker is enabled in the follow-up project') unless tracker

      author = follow_up_author
      issue = Issue.new(project: project, tracker: tracker, author: author)
      issue.status ||= tracker.default_status
      issue.priority ||= IssuePriority.default || IssuePriority.active.first
      issue.subject = "CSAT follow-up: Issue ##{original_issue.id} - #{original_issue.subject}".truncate(255)
      issue.description = description
      issue.is_private = Settings.follow_up_private?
      assign(issue, project, tracker)

      saved = as_user(author) { issue.save }
      return record_error(issue.errors.full_messages.join(', ')) unless saved

      response.update_columns(follow_up_issue_id: issue.id, follow_up_error: nil)
      relate(issue)
      issue
    end

    def add_change_note
      notes = []
      if @previous && @previous[:rating] != response.rating
        notes << "The customer changed the rating from #{rating_label(@previous[:rating])} " \
                 "to #{rating_label(response.rating)}."
      end
      if @previous && @previous[:comment].to_s != response.comment.to_s
        notes << "Updated customer comment:\n\n#{quote(response.comment)}"
      end
      return if notes.empty?

      author = follow_up_author
      follow_up_issue.init_journal(author, notes.join("\n\n"))
      return if as_user(author) { follow_up_issue.save }

      Rails.logger.error("[redmine_csat] could not add a note to follow-up ##{follow_up_issue.id}: " \
                         "#{follow_up_issue.errors.full_messages.join(', ')}")
    end

    def description
      <<~TEXT
        A customer rated issue ##{original_issue.id} as #{rating_label(response.rating)}.

        Customer: #{response.customer_user&.name || response.csat_request&.recipient_email}

        Comment:

        #{quote(response.comment)}
      TEXT
    end

    # Customer text is untrusted: wrapping it in <pre> stops it being rendered
    # as markup or running macros, in both Textile and Markdown.
    def quote(text)
      return '(none)' if text.blank?

      "<pre>#{text.gsub(%r{</pre}i, '< /pre')}</pre>"
    end

    def rating_label(rating)
      Settings.labels[RedmineCsatResponse::RATING_NAMES[rating]&.to_sym] || rating.to_s
    end

    def target_project
      configured = Project.find_by(id: Settings.follow_up_project_id) if Settings.follow_up_project_id
      configured&.active? ? configured : original_issue.project
    end

    def pick_tracker(project)
      trackers = project.trackers.to_a
      preferred = [Tracker.find_by(id: Settings.follow_up_tracker_id), original_issue.tracker].compact
      preferred.find { |tracker| trackers.include?(tracker) } || trackers.first
    end

    def follow_up_author
      configured = User.active.find_by(id: Settings.follow_up_author_id) if Settings.follow_up_author_id
      assignee = original_issue.assigned_to
      configured ||
        (assignee if assignee.is_a?(User) && assignee.active?) ||
        User.active.where(admin: true).order(:id).first ||
        User.anonymous
    end

    def assign(issue, project, tracker)
      assignee_id = Settings.follow_up_assignee_id
      return unless assignee_id

      assignee = Principal.find_by(id: assignee_id)
      if assignee && project.assignable_users(tracker).include?(assignee)
        issue.assigned_to = assignee
      else
        Rails.logger.warn("[redmine_csat] follow-up assignee ##{assignee_id} is not assignable " \
                          "in project #{project.identifier}; leaving the follow-up unassigned")
      end
    end

    def relate(issue)
      return unless issue.project == original_issue.project || Setting.cross_project_issue_relations?

      IssueRelation.create(issue_from: issue, issue_to: original_issue,
                           relation_type: IssueRelation::TYPE_RELATES)
    end

    def as_user(user)
      previous_user = User.current
      User.current = user
      yield
    ensure
      User.current = previous_user
    end

    def record_error(message)
      Rails.logger.error("[redmine_csat] follow-up for issue ##{response.issue_id} failed: #{message}")
      response.update_columns(follow_up_error: message.to_s.truncate(255)) if response.persisted?
      nil
    end
  end
end
