# frozen_string_literal: true

class CreateRecruitingActivityLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :recruiting_activity_logs do |t|
      t.references :shift, null: false, foreign_key: true
      t.references :worker_profile, null: true, foreign_key: true
      t.references :shift_assignment, null: true, foreign_key: true
      t.string :action, null: false
      t.jsonb :details, default: {}
      t.string :source, null: false, default: 'algorithm'

      t.timestamps
    end

    add_index :recruiting_activity_logs, [:shift_id, :created_at]
    add_index :recruiting_activity_logs, [:shift_id, :action]
    add_index :recruiting_activity_logs, :details, using: :gin
  end
end
