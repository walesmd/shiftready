class CreateBlockLists < ActiveRecord::Migration[8.1]
  def change
    create_table :block_lists do |t|
      # Polymorphic associations for blocker (who initiated the block)
      t.string :blocker_type, null: false
      t.bigint :blocker_id, null: false

      # Polymorphic associations for blocked (who is being blocked)
      t.string :blocked_type, null: false
      t.bigint :blocked_id, null: false

      # Optional reason for the block
      t.text :reason

      t.timestamps
    end

    # Add composite indexes
    add_index :block_lists, [:blocker_type, :blocker_id]
    add_index :block_lists, [:blocked_type, :blocked_id]
    add_index :block_lists, [:blocker_type, :blocker_id, :blocked_type, :blocked_id],
              unique: true, name: 'index_block_lists_unique'
  end
end
