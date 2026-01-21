class CreateWorkerPreferredJobTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :worker_preferred_job_types do |t|
      t.references :worker_profile, null: false, foreign_key: true
      t.string :job_type, null: false

      t.timestamps
    end

    # Add unique composite index to prevent duplicates
    add_index :worker_preferred_job_types, [:worker_profile_id, :job_type], unique: true, name: 'index_worker_pref_job_types_unique'
  end
end
