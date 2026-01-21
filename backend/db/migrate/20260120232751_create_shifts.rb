class CreateShifts < ActiveRecord::Migration[8.1]
  def change
    create_table :shifts do |t|
      # Foreign keys
      t.references :company, null: false, foreign_key: true
      t.references :work_location, null: false, foreign_key: true
      t.bigint :created_by_employer_id, null: false

      # Shift details
      t.string :title, null: false
      t.text :description, null: false
      t.string :job_type, null: false
      t.datetime :start_datetime, null: false
      t.datetime :end_datetime, null: false
      t.integer :pay_rate_cents, null: false
      t.integer :slots_total, default: 1
      t.integer :slots_filled, default: 0

      # Status tracking
      t.integer :status, default: 0, null: false # enum: draft=0, posted=1, recruiting=2, filled=3, in_progress=4, completed=5, cancelled=6
      t.datetime :posted_at
      t.datetime :recruiting_started_at
      t.datetime :filled_at
      t.datetime :completed_at
      t.datetime :cancelled_at
      t.text :cancellation_reason

      # Requirements
      t.integer :min_workers_needed, default: 1
      t.text :skills_required
      t.text :physical_requirements

      t.timestamps
    end

    # Add indexes
    add_index :shifts, :status
    add_index :shifts, :job_type
    add_index :shifts, :start_datetime
    add_index :shifts, [:status, :start_datetime], name: 'index_shifts_on_status_and_start_datetime'
    add_index :shifts, :created_by_employer_id

    # Add foreign key for created_by_employer_id
    add_foreign_key :shifts, :employer_profiles, column: :created_by_employer_id
  end
end
