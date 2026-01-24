class AddOwnerEmployerProfileToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :owner_employer_profile_id, :bigint
    add_index :companies, :owner_employer_profile_id
    add_foreign_key :companies, :employer_profiles, column: :owner_employer_profile_id
  end
end
