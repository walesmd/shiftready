class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      # Foreign keys
      t.references :shift_assignment, null: false, foreign_key: true, index: { unique: true }
      t.references :worker_profile, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true

      # Payment details
      t.integer :amount_cents, null: false
      t.string :currency, default: 'USD', null: false
      t.integer :pay_rate_cents # Snapshot from shift at time of payment
      t.decimal :hours_worked, precision: 5, scale: 2

      # Payment processing
      t.integer :status, default: 0, null: false # enum: pending=0, processing=1, completed=2, failed=3, refunded=4, disputed=5
      t.integer :payment_method, default: 0 # enum: direct_deposit=0, check=1, stripe=2
      t.string :external_transaction_id
      t.datetime :processed_at
      t.datetime :failed_at
      t.text :failure_reason
      t.datetime :refunded_at
      t.text :refund_reason

      # Dispute handling
      t.datetime :disputed_at
      t.text :dispute_reason
      t.datetime :dispute_resolved_at
      t.text :dispute_resolution

      # Tax & compliance (1099 tracking)
      t.integer :tax_year
      t.boolean :included_in_1099, default: false

      t.timestamps
    end

    # Add indexes
    add_index :payments, :status
    add_index :payments, :tax_year
    add_index :payments, [:worker_profile_id, :tax_year], name: 'index_payments_on_worker_and_tax_year'
  end
end
