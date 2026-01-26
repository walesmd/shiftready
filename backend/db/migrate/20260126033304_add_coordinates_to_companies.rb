class AddCoordinatesToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :billing_latitude, :decimal, precision: 10, scale: 6
    add_column :companies, :billing_longitude, :decimal, precision: 10, scale: 6
    add_index :companies, [:billing_latitude, :billing_longitude], name: 'index_companies_on_billing_coordinates'
  end
end
