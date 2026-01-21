class CreateEmployerProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :employer_profiles do |t|
      # Foreign keys
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.references :company, null: false, foreign_key: true

      # Personal information
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :title # Job title at company
      t.string :phone, null: false

      # Onboarding
      t.boolean :onboarding_completed, default: false
      t.datetime :terms_accepted_at
      t.datetime :msa_accepted_at # Master Service Agreement

      # Permissions
      t.boolean :can_post_shifts, default: true
      t.boolean :can_approve_timesheets, default: false
      t.boolean :is_billing_contact, default: false

      t.timestamps
    end
  end
end
