# frozen_string_literal: true

class ShiftAssignment < ApplicationRecord
  # Associations
  belongs_to :shift
  belongs_to :worker_profile
  has_one :payment, dependent: :destroy
  belongs_to :timesheet_approved_by_employer, class_name: 'EmployerProfile', optional: true
  has_many :recruiting_activity_logs, dependent: :nullify

  # Enums
  enum :assigned_by, { algorithm: 0, manual_admin: 1, worker_self_select: 2 }
  enum :response_method, { sms: 0, app: 1, phone_call: 2, email: 3 }
  enum :response_value, { accepted: 0, declined: 1, no_response: 2 }, prefix: :response
  enum :status, {
    offered: 0,
    accepted: 1,
    declined: 2,
    no_response: 3,
    confirmed: 4,
    checked_in: 5,
    no_show: 6,
    completed: 7,
    cancelled: 8
  }
  enum :cancelled_by, { worker: 0, employer: 1, admin: 2, system: 3 }

  # Validations
  validates :shift_id, uniqueness: { scope: :worker_profile_id, message: 'Worker already assigned to this shift' }
  validates :assigned_at, presence: true
  validates :worker_rating, inclusion: { in: 1..5 }, allow_nil: true
  validates :employer_rating, inclusion: { in: 1..5 }, allow_nil: true
  validate :actual_end_time_after_start_time, if: :actual_end_time?

  # Scopes
  scope :active, -> { where(status: [:offered, :accepted, :confirmed, :checked_in]) }
  scope :pending_response, -> { where(status: :offered) }
  scope :accepted_assignments, -> { where(status: [:accepted, :confirmed, :checked_in, :completed]) }
  scope :needs_timesheet_approval, -> { where(status: :checked_in).where(timesheet_approved_at: nil) }
  scope :completed_shifts, -> { where(status: :completed) }
  scope :for_worker, ->(worker_id) { where(worker_profile_id: worker_id) }
  scope :for_shift, ->(shift_id) { where(shift_id: shift_id) }
  scope :recent, -> { order(assigned_at: :desc) }

  # Callbacks
  before_validation :set_assigned_at_default
  after_update :update_worker_stats, if: :saved_change_to_status?
  after_commit :trigger_resume_recruiting, if: :just_cancelled_and_can_resume_recruiting?, on: :update

  # Instance methods - Status transitions
  def accept!(method: :sms)
    return false unless offered?

    transaction do
      update!(
        status: :accepted,
        accepted_at: Time.current,
        response_received_at: Time.current,
        response_method: method,
        response_value: :accepted
      )
      shift.increment!(:slots_filled)
    end
  end

  def decline!(reason = nil, method: :sms)
    return false unless offered?

    update!(
      status: :declined,
      response_received_at: Time.current,
      response_method: method,
      response_value: :declined,
      decline_reason: reason
    )
  end

  def mark_no_response!
    return false unless offered?

    update!(
      status: :no_response,
      response_value: :no_response
    )
  end

  def confirm!
    return false unless accepted?

    update!(
      status: :confirmed,
      confirmed_at: Time.current
    )
  end

  def check_in!(time = Time.current)
    return false unless can_check_in?

    update!(
      status: :checked_in,
      checked_in_at: time,
      actual_start_time: time
    )
  end

  def check_out!(time = Time.current)
    return false unless checked_in?

    hours = calculate_hours_worked(time)

    update!(
      checked_out_at: time,
      actual_end_time: time,
      actual_hours_worked: hours
    )
  end

  def approve_timesheet!(employer)
    return false unless checked_out? && !timesheet_approved?

    update!(
      timesheet_approved_at: Time.current,
      timesheet_approved_by_employer: employer
    )
  end

  def mark_complete!
    return false unless checked_out? && timesheet_approved?

    update!(
      status: :completed,
      completed_successfully: true
    )
  end

  def mark_no_show!
    return false unless [offered?, accepted?, confirmed?].any?

    was_accepted_or_confirmed = accepted? || confirmed?

    transaction do
      update!(
        status: :no_show,
        no_show: true,
        completed_successfully: false
      )
      worker_profile.increment!(:no_show_count)
      shift.decrement!(:slots_filled) if was_accepted_or_confirmed
      true
    end
  end

  def cancel!(by:, reason: nil)
    return false if completed? || cancelled?

    was_accepted_or_beyond = accepted? || confirmed? || checked_in?

    transaction do
      update!(
        status: :cancelled,
        cancelled_at: Time.current,
        cancelled_by: by,
        cancellation_reason: reason
      )
      shift.decrement!(:slots_filled) if was_accepted_or_beyond
      true
    end
  end

  # Query methods
  def can_check_in?
    (accepted? || confirmed?) && shift.start_datetime <= Time.current
  end

  def checked_out?
    checked_out_at.present?
  end

  def timesheet_approved?
    timesheet_approved_at.present?
  end

  def ready_for_payment?
    completed? && timesheet_approved? && payment.nil?
  end

  # Response time tracking
  def response_time_minutes
    return nil unless response_received_at && sms_sent_at
    ((response_received_at - sms_sent_at) / 60).round
  end

  # Pay calculation
  def calculated_pay_cents
    return 0 unless actual_hours_worked && shift.pay_rate_cents
    (actual_hours_worked * shift.pay_rate_cents).to_i
  end

  def formatted_calculated_pay
    "$#{(calculated_pay_cents / 100.0).round(2)}"
  end

  # Display helpers
  def worker_name
    worker_profile.full_name
  end

  def shift_title
    shift.title
  end

  def status_display
    status.titleize
  end

  private

  def set_assigned_at_default
    self.assigned_at ||= Time.current
  end

  def actual_end_time_after_start_time
    if actual_end_time <= actual_start_time
      errors.add(:actual_end_time, 'must be after actual start time')
    end
  end

  def calculate_hours_worked(end_time)
    return 0 unless actual_start_time
    ((end_time - actual_start_time) / 1.hour).round(2)
  end

  def update_worker_stats
    case status
    when 'completed'
      worker_profile.increment!(:total_shifts_completed)
      worker_profile.update_reliability_score!
    when 'no_show'
      # Already handled in mark_no_show!
      worker_profile.update_reliability_score!
    end
  end

  def just_cancelled?
    saved_change_to_status? && cancelled?
  end

  def just_cancelled_and_can_resume_recruiting?
    return false unless just_cancelled?

    shift.reload
    shift.can_resume_recruiting?
  end

  def trigger_resume_recruiting
    ResumeRecruitingJob.perform_later(shift.id)
  end
end
