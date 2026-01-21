class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      # Polymorphic association
      t.string :messageable_type, null: false
      t.bigint :messageable_id, null: false

      # Optional associations
      t.references :shift, foreign_key: true
      t.references :shift_assignment, foreign_key: true

      # Message content
      t.integer :direction, null: false # enum: inbound=0, outbound=1
      t.integer :channel, null: false # enum: sms=0, email=1, in_app=2, phone_call=3
      t.string :subject
      t.text :body, null: false
      t.integer :message_type, default: 0 # enum: shift_offer=0, reminder=1, confirmation=2, update=3, general=4

      # SMS-specific (Twilio)
      t.string :twilio_message_sid
      t.string :from_phone
      t.string :to_phone
      t.integer :sms_status # enum: queued=0, sent=1, delivered=2, failed=3, undelivered=4
      t.string :sms_error_code
      t.text :sms_error_message

      # Delivery tracking
      t.datetime :sent_at
      t.datetime :delivered_at
      t.datetime :read_at
      t.datetime :failed_at

      # Threading
      t.uuid :thread_id
      t.bigint :in_reply_to_message_id

      t.timestamps
    end

    # Add indexes
    add_index :messages, [:messageable_type, :messageable_id]
    add_index :messages, :twilio_message_sid, unique: true
    add_index :messages, :thread_id
    add_index :messages, :sent_at
    add_index :messages, [:messageable_type, :messageable_id, :sent_at], name: 'index_messages_on_messageable_and_sent_at'
    add_index :messages, :in_reply_to_message_id

    # Add foreign key for threading
    add_foreign_key :messages, :messages, column: :in_reply_to_message_id
  end
end
