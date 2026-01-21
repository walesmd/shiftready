class AddBusinessDetailsToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :workers_needed_per_week, :string
    add_column :companies, :typical_roles, :text
  end
end
