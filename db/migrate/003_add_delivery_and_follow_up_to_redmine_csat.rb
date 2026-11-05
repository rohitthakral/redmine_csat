# frozen_string_literal: true

# - Tracks whether the survey email was actually delivered.
# - Links each response to the single follow-up issue it created, and records
#   why creating one failed.
# - Enforces one survey per issue in the database (the old index on issue_id
#   was not unique), after removing duplicates and orphaned rows.
class AddDeliveryAndFollowUpToRedmineCsat < ActiveRecord::Migration[7.2]
  class CsatRequest < ActiveRecord::Base
    self.table_name = 'redmine_csat_requests'
  end

  class CsatResponse < ActiveRecord::Base
    self.table_name = 'redmine_csat_responses'
  end

  def up
    add_column :redmine_csat_requests, :delivered_at, :datetime
    add_column :redmine_csat_responses, :follow_up_issue_id, :integer
    add_column :redmine_csat_responses, :follow_up_error, :string, limit: 255

    # Surveys sent before this migration are assumed to have been delivered.
    CsatRequest.reset_column_information
    CsatRequest.update_all('delivered_at = sent_at')

    remove_orphans
    remove_duplicate_requests

    remove_index :redmine_csat_requests, :issue_id
    add_index :redmine_csat_requests, :issue_id, unique: true
    add_index :redmine_csat_responses, :follow_up_issue_id
  end

  def down
    remove_index :redmine_csat_responses, :follow_up_issue_id
    remove_index :redmine_csat_requests, :issue_id
    add_index :redmine_csat_requests, :issue_id
    remove_column :redmine_csat_responses, :follow_up_error
    remove_column :redmine_csat_responses, :follow_up_issue_id
    remove_column :redmine_csat_requests, :delivered_at
  end

  private

  def remove_orphans
    CsatRequest.where("issue_id NOT IN (SELECT id FROM #{quote_table_name('issues')})").delete_all
    CsatResponse.where.not(request_id: CsatRequest.select(:id)).delete_all
  end

  # Keep the request that has a response (or the oldest one) for each issue.
  def remove_duplicate_requests
    duplicated = CsatRequest.group(:issue_id).having('COUNT(*) > 1').pluck(:issue_id)
    duplicated.each do |issue_id|
      ids = CsatRequest.where(issue_id: issue_id).order(:id).pluck(:id)
      keep = CsatResponse.where(request_id: ids).order(:id).pick(:request_id) || ids.first
      drop = ids - [keep]
      CsatResponse.where(request_id: drop).delete_all
      CsatRequest.where(id: drop).delete_all
    end
  end
end
