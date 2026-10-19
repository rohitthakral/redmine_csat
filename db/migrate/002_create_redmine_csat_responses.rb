# frozen_string_literal: true

class CreateRedmineCsatResponses < ActiveRecord::Migration[7.2]
  def change
    create_table :redmine_csat_responses do |t|
      t.integer :request_id, null: false
      t.integer :issue_id, null: false
      t.integer :project_id, null: false
      t.integer :customer_user_id
      t.integer :agent_user_id
      t.integer :rating, null: false
      t.text :comment
      t.datetime :responded_at, null: false
      t.string :ip_hash, limit: 64
      t.timestamps null: false
    end

    add_index :redmine_csat_responses, :request_id, unique: true
    add_index :redmine_csat_responses, :issue_id
    add_index :redmine_csat_responses, :project_id
    add_index :redmine_csat_responses, [:project_id, :responded_at],
              name: 'idx_csat_responses_project_date'
  end
end
