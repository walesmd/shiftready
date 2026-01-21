class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      # Company information
      t.string :name, null: false
      t.string :industry

      # Billing contact info
      t.string :billing_email
      t.string :billing_phone
      t.string :billing_address_line_1
      t.string :billing_address_line_2
      t.string :billing_city
      t.string :billing_state
      t.string :billing_zip_code

      # Tax and payment info
      t.string :tax_id # EIN for invoicing
      t.string :payment_terms # e.g., "Net 30"

      # Status
      t.boolean :is_active, default: true

      t.timestamps
    end

    # Add index on name for lookups
    add_index :companies, :name
  end
end
