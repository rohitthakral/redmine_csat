# frozen_string_literal: true

class CreateRedmineCsatRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :redmine_csat_requests do |t|
      t.integer :issue_id, null: false
      t.integer :project_id, null: false
      t.integer :journal_id
      t.integer :customer_user_id
      t.integer :agent_user_id
      t.string :recipient_email, null: false, limit: 255
      t.string :recipient_email_normalized, null: false, limit: 255
      t.string :token_digest, null: false, limit: 64
      t.datetime :sent_at, null: false
      t.datetime :responded_at
      t.timestamps null: false
    end

    add_index :redmine_csat_requests, :issue_id
    add_index :redmine_csat_requests, :project_id
    add_index :redmine_csat_requests, :recipient_email_normalized,
              name: 'idx_csat_requests_recipient_email'
    add_index :redmine_csat_requests, :token_digest, unique: true
    add_index :redmine_csat_requests, [:recipient_email_normalized, :sent_at],
              name: 'idx_csat_requests_recipient_sent'
  end
end
