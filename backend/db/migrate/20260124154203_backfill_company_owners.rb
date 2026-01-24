class BackfillCompanyOwners < ActiveRecord::Migration[8.1]
  def up
    # Set the first employer profile as the owner for each company that doesn't have one
    Company.where(owner_employer_profile_id: nil).find_each do |company|
      first_employer = company.employer_profiles.order(:created_at).first
      if first_employer
        company.update_column(:owner_employer_profile_id, first_employer.id)
      end
    end
  end

  def down
    # Optional: Remove owner associations if rolling back
    # Company.update_all(owner_employer_profile_id: nil)
  end
end
