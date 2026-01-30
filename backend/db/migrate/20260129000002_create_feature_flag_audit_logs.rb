# frozen_string_literal: true

class CreateFeatureFlagAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :feature_flag_audit_logs do |t|
      t.references :feature_flag, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.jsonb :previous_value
      t.jsonb :new_value
      t.jsonb :details, null: false, default: {}

      t.timestamps
    end

    add_index :feature_flag_audit_logs, :action
    add_index :feature_flag_audit_logs, :created_at
  end
end
