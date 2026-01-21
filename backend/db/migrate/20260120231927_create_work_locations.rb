class CreateWorkLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :work_locations do |t|
      # Foreign key
      t.references :company, null: false, foreign_key: true

      # Location information
      t.string :name, null: false # e.g., "Downtown Warehouse"
      t.string :address_line_1, null: false
      t.string :address_line_2
      t.string :city, null: false
      t.string :state, null: false
      t.string :zip_code, null: false
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6

      # Additional info for workers
      t.text :arrival_instructions # "Ask for Mike at loading dock"
      t.text :parking_notes

      # Status
      t.boolean :is_active, default: true

      t.timestamps
    end

    # Add indexes
    add_index :work_locations, [:latitude, :longitude], name: 'index_work_locations_on_coordinates'
  end
end
