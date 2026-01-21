class CreateShiftAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :shift_assignments do |t|
      # Foreign keys
      t.references :shift, null: false, foreign_key: true
      t.references :worker_profile, null: false, foreign_key: true

      # Assignment metadata
      t.datetime :assigned_at, null: false
      t.integer :assigned_by, default: 0 # enum: algorithm=0, manual_admin=1, worker_self_select=2
      t.decimal :algorithm_score, precision: 5, scale: 2
      t.decimal :distance_miles, precision: 5, scale: 2

      # Recruiting timeline (TEMPORAL DATA - critical for observability)
      t.datetime :sms_sent_at
      t.datetime :sms_delivered_at
      t.datetime :response_received_at
      t.integer :response_method # enum: sms=0, app=1, phone_call=2, email=3
      t.integer :response_value # enum: accepted=0, declined=1, no_response=2
      t.text :decline_reason

      # Acceptance & status
      t.integer :status, null: false, default: 0 # enum: offered=0, accepted=1, declined=2, no_response=3, confirmed=4, checked_in=5, no_show=6, completed=7, cancelled=8
      t.datetime :accepted_at
      t.datetime :confirmed_at
      t.datetime :cancelled_at
      t.text :cancellation_reason
      t.integer :cancelled_by # enum: worker=0, employer=1, admin=2, system=3

      # Timesheet tracking
      t.datetime :checked_in_at
      t.datetime :checked_out_at
      t.datetime :actual_start_time
      t.datetime :actual_end_time
      t.decimal :actual_hours_worked, precision: 5, scale: 2
      t.datetime :timesheet_approved_at
      t.bigint :timesheet_approved_by_employer_id

      # Performance & rating
      t.integer :worker_rating # 1-5 stars from employer
      t.integer :employer_rating # 1-5 stars from worker
      t.text :worker_feedback
      t.text :employer_feedback
      t.boolean :no_show, default: false
      t.boolean :completed_successfully

      t.timestamps
    end

    # Add indexes
    add_index :shift_assignments, :status
    add_index :shift_assignments, :assigned_at
    add_index :shift_assignments, [:shift_id, :worker_profile_id], unique: true, name: 'index_shift_assignments_unique'
    add_index :shift_assignments, [:status, :assigned_at], name: 'index_shift_assignments_on_status_and_assigned_at'
    add_index :shift_assignments, :timesheet_approved_by_employer_id

    # Add foreign key for timesheet approver
    add_foreign_key :shift_assignments, :employer_profiles, column: :timesheet_approved_by_employer_id
  end
end
