class CreateWorkerProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :worker_profiles do |t|
      # Foreign key to users table
      t.references :user, null: false, foreign_key: true, index: { unique: true }

      # Personal information
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :phone, null: false
      t.string :address_line_1, null: false
      t.string :address_line_2
      t.string :city, null: false
      t.string :state, null: false, default: 'TX'
      t.string :zip_code, null: false
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6

      # Profile completeness
      t.boolean :onboarding_completed, default: false
      t.datetime :terms_accepted_at
      t.datetime :sms_consent_given_at
      t.boolean :over_18_confirmed, default: false

      # Performance metrics (for algorithm)
      t.integer :total_shifts_completed, default: 0
      t.integer :total_shifts_assigned, default: 0
      t.integer :no_show_count, default: 0
      t.decimal :average_rating, precision: 3, scale: 2
      t.decimal :reliability_score, precision: 5, scale: 2

      # Payment info (for 1099)
      t.string :ssn_encrypted
      t.integer :preferred_payment_method, default: 0 # 0: direct_deposit, 1: check
      t.string :bank_account_last_4

      # Activity tracking
      t.datetime :last_sms_sent_at
      t.datetime :last_sms_response_at
      t.integer :average_response_time_minutes
      t.boolean :is_active, default: true

      t.timestamps
    end

    # Add indexes
    add_index :worker_profiles, :phone, unique: true
    add_index :worker_profiles, :zip_code
    add_index :worker_profiles, [:latitude, :longitude], name: 'index_worker_profiles_on_coordinates'
  end
end
