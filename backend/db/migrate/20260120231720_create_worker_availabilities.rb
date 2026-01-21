class CreateWorkerAvailabilities < ActiveRecord::Migration[8.1]
  def change
    create_table :worker_availabilities do |t|
      t.references :worker_profile, null: false, foreign_key: true

      # Availability window
      t.integer :day_of_week, null: false # 0=Sunday, 6=Saturday
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.boolean :is_active, default: true

      t.timestamps
    end

    # Add indexes
    add_index :worker_availabilities, [:worker_profile_id, :day_of_week], name: 'index_worker_avail_on_profile_and_day'
  end
end
