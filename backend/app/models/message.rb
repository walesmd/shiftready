# frozen_string_literal: true

class Message < ApplicationRecord
  # Associations
  belongs_to :messageable, polymorphic: true
  belongs_to :shift, optional: true
  belongs_to :shift_assignment, optional: true
  belongs_to :reply_to_message, class_name: 'Message', foreign_key: :in_reply_to_message_id, optional: true
  has_many :replies, class_name: 'Message', foreign_key: :in_reply_to_message_id, dependent: :nullify

  # Enums
  enum :direction, { inbound: 0, outbound: 1 }
  enum :channel, { sms: 0, email: 1, in_app: 2, phone_call: 3 }
  enum :message_type, { shift_offer: 0, reminder: 1, confirmation: 2, status_update: 3, general: 4 }
  enum :sms_status, { queued: 0, sent: 1, delivered: 2, failed: 3, undelivered: 4 }

  # Validations
  validates :body, presence: true
  validates :twilio_message_sid, uniqueness: true, allow_nil: true
  validates :direction, :channel, presence: true
  validate :phone_numbers_present_for_sms

  # Scopes
  scope :for_messageable, ->(messageable) { where(messageable: messageable) }
  scope :inbound_messages, -> { where(direction: :inbound) }
  scope :outbound_messages, -> { where(direction: :outbound) }
  scope :sms_messages, -> { where(channel: :sms) }
  scope :email_messages, -> { where(channel: :email) }
  scope :for_shift, ->(shift_id) { where(shift_id: shift_id) }
  scope :for_thread, ->(thread_id) { where(thread_id: thread_id) }
  scope :recent, -> { order(sent_at: :desc) }
  scope :delivered_messages, -> { where(sms_status: :delivered) }
  scope :failed_messages, -> { where(sms_status: [:failed, :undelivered]) }

  # Callbacks
  before_create :generate_thread_id, unless: :thread_id?
  before_create :set_sent_at_default

  # Instance methods
  def mark_sent!(twilio_sid = nil)
    update_attrs = {
      sms_status: :sent,
      sent_at: Time.current
    }
    update_attrs[:twilio_message_sid] = twilio_sid if twilio_sid

    update!(update_attrs)
  end

  def mark_delivered!
    return false unless sent?

    update!(
      sms_status: :delivered,
      delivered_at: Time.current
    )
  end

  def mark_failed!(error_code = nil, error_message = nil)
    update!(
      sms_status: :failed,
      failed_at: Time.current,
      sms_error_code: error_code,
      sms_error_message: error_message
    )
  end

  def mark_read!
    update!(read_at: Time.current)
  end

  def reply(body:, channel: self.channel)
    Message.create!(
      messageable: messageable,
      shift: shift,
      shift_assignment: shift_assignment,
      direction: opposite_direction,
      channel: channel,
      body: body,
      thread_id: thread_id,
      in_reply_to_message_id: id,
      from_phone: to_phone, # Swap phones for reply
      to_phone: from_phone
    )
  end

  # Query methods
  def delivered?
    sms_status == 'delivered'
  end

  def read?
    read_at.present?
  end

  def is_reply?
    in_reply_to_message_id.present?
  end

  def has_replies?
    replies.exists?
  end

  # Display helpers
  def sender_name
    if inbound?
      messageable.respond_to?(:full_name) ? messageable.full_name : messageable.class.name
    else
      'ShiftReady'
    end
  end

  def recipient_name
    if outbound?
      messageable.respond_to?(:full_name) ? messageable.full_name : messageable.class.name
    else
      'ShiftReady'
    end
  end

  def status_display
    if sms?
      sms_status&.titleize || 'Unknown'
    else
      delivered_at ? 'Delivered' : 'Pending'
    end
  end

  def formatted_sent_at
    sent_at&.strftime('%b %d, %Y at %I:%M %p')
  end

  def short_body(length = 100)
    return body if body.length <= length
    "#{body[0..length]}..."
  end

  private

  def generate_thread_id
    self.thread_id = SecureRandom.uuid
  end

  def set_sent_at_default
    self.sent_at ||= Time.current if outbound?
  end

  def opposite_direction
    inbound? ? :outbound : :inbound
  end

  def phone_numbers_present_for_sms
    return unless sms?

    if from_phone.blank?
      errors.add(:from_phone, 'must be present for SMS messages')
    end

    if to_phone.blank?
      errors.add(:to_phone, 'must be present for SMS messages')
    end
  end
end
