class AddUniqueIndexToWorkerAvailabilities < ActiveRecord::Migration[8.1]
  def change
    add_index :worker_availabilities,
              [:worker_profile_id, :day_of_week, :start_time, :end_time],
              unique: true,
              name: 'index_worker_availabilities_on_profile_day_time'
  end
end
