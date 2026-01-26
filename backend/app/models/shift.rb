# frozen_string_literal: true

class Shift < ApplicationRecord
  # Associations
  belongs_to :company
  belongs_to :work_location
  belongs_to :created_by_employer, class_name: 'EmployerProfile', foreign_key: :created_by_employer_id
  has_many :shift_assignments, dependent: :destroy
  has_many :workers, through: :shift_assignments, source: :worker_profile
  has_many :recruiting_activity_logs, dependent: :destroy

  # Enums
  enum :status, {
    draft: 0,
    posted: 1,
    recruiting: 2,
    filled: 3,
    in_progress: 4,
    completed: 5,
    cancelled: 6
  }

  # Validations
  validates :title, :description, :job_type, :start_datetime, :end_datetime, :pay_rate_cents, presence: true
  validates :pay_rate_cents, numericality: { greater_than: 0 }
  validates :slots_total, :slots_filled, :min_workers_needed, numericality: { greater_than_or_equal_to: 0 }
  validates :job_type, inclusion: { in: WorkerPreferredJobType::AVAILABLE_JOB_TYPES }
  validates :tracking_code, presence: true, uniqueness: true
  validates :tracking_code, format: { with: /\ASR-[A-F0-9]{6}\z/ }, allow_blank: true
  validate :end_datetime_after_start_datetime
  validate :min_workers_not_greater_than_slots
  validate :tracking_code_immutable, on: :update

  # Scopes
  scope :active, -> { where.not(status: [:cancelled, :completed]) }
  scope :recruiting, -> { where(status: :recruiting) }
  scope :upcoming, -> { where('start_datetime > ?', Time.current) }
  scope :past, -> { where('start_datetime < ?', Time.current) }
  scope :for_job_type, ->(type) { where(job_type: type) }
  scope :for_company, ->(company_id) { where(company_id: company_id) }
  scope :starting_soon, -> { upcoming.order(start_datetime: :asc) }
  scope :needs_workers, -> { where('slots_filled < slots_total') }
  scope :by_tracking_code, ->(code) { code.present? ? where(tracking_code: code.upcase) : none }

  # Callbacks
  before_validation :generate_tracking_code, on: :create
  before_validation :set_min_workers_default
  after_update :check_if_filled

  # Class methods
  def self.generate_unique_tracking_code
    loop do
      code = "SR-#{SecureRandom.hex(3).upcase}"
      break code unless exists?(tracking_code: code)
    end
  end

  # Instance methods
  def hourly_rate
    pay_rate_cents / 100.0
  end

  def formatted_pay_rate
    "$#{hourly_rate}/hr"
  end

  def duration_hours
    return 0 unless start_datetime && end_datetime
    ((end_datetime - start_datetime) / 1.hour).round(2)
  end

  def estimated_pay
    hourly_rate * duration_hours
  end

  def formatted_estimated_pay
    "$#{estimated_pay.round(2)}"
  end

  def slots_available
    slots_total - slots_filled
  end

  def fully_filled?
    slots_filled >= slots_total
  end

  def can_start_recruiting?
    posted? && !fully_filled? && upcoming?
  end

  def upcoming?
    start_datetime > Time.current
  end

  def in_past?
    start_datetime < Time.current
  end

  def start_recruiting!
    return false unless can_start_recruiting?

    update!(
      status: :recruiting,
      recruiting_started_at: Time.current
    )
  end

  def mark_as_filled!
    return false unless fully_filled?

    update!(
      status: :filled,
      filled_at: Time.current
    )
  end

  def cancel!(reason = nil)
    update!(
      status: :cancelled,
      cancelled_at: Time.current,
      cancellation_reason: reason
    )
  end

  def start!
    return false unless filled? && start_datetime <= Time.current

    update!(status: :in_progress)
  end

  def complete!
    return false unless in_progress? && end_datetime <= Time.current

    update!(
      status: :completed,
      completed_at: Time.current
    )
  end

  def formatted_datetime_range
    return '' unless start_datetime && end_datetime

    if start_datetime.to_date == end_datetime.to_date
      "#{start_datetime.strftime('%b %d, %Y')} from #{start_datetime.strftime('%I:%M %p')} to #{end_datetime.strftime('%I:%M %p')}"
    else
      "#{start_datetime.strftime('%b %d, %I:%M %p')} - #{end_datetime.strftime('%b %d, %I:%M %p')}"
    end
  end

  def can_be_deleted?
    # Can only delete draft shifts or shifts with no accepted assignments
    draft? || shift_assignments.accepted_assignments.empty?
  end

  def can_resume_recruiting?
    (filled? || recruiting?) && !fully_filled? && start_datetime > 24.hours.from_now
  end

  private

  def end_datetime_after_start_datetime
    return if end_datetime.blank? || start_datetime.blank?

    if end_datetime <= start_datetime
      errors.add(:end_datetime, 'must be after start datetime')
    end
  end

  def min_workers_not_greater_than_slots
    return if min_workers_needed.blank? || slots_total.blank?

    if min_workers_needed > slots_total
      errors.add(:min_workers_needed, 'cannot be greater than total slots')
    end
  end

  def set_min_workers_default
    self.min_workers_needed ||= 1
  end

  def check_if_filled
    if slots_filled >= slots_total && (recruiting? || posted?)
      mark_as_filled!
    end
  end

  def generate_tracking_code
    self.tracking_code ||= self.class.generate_unique_tracking_code
  end

  def tracking_code_immutable
    if tracking_code_changed? && tracking_code_was.present?
      errors.add(:tracking_code, "cannot be changed after creation")
    end
  end
end
