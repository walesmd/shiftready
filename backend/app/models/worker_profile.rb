# frozen_string_literal: true

class WorkerProfile < ApplicationRecord
  include WorkerProfileAlgorithmScopes
  include Geocodable
  include PhoneNormalizable

  # Associations
  belongs_to :user
  has_many :worker_availabilities, dependent: :destroy
  has_many :worker_preferred_job_types, dependent: :destroy
  has_many :shift_assignments, dependent: :destroy
  has_many :shifts, through: :shift_assignments
  has_many :messages, as: :messageable
  has_many :payments, through: :shift_assignments
  has_many :recruiting_activity_logs, dependent: :nullify

  # Enums
  enum :preferred_payment_method, { direct_deposit: 0, check: 1 }

  # Validations
  validates :first_name, :last_name, :phone, :address_line_1, :city, :state, :zip_code, presence: true
  validates :phone, uniqueness: true, format: { with: /\A\+1\d{10}\z/, message: 'must be a valid phone number' }
  validates :zip_code, format: { with: /\A\d{5}(-\d{4})?\z/, message: 'must be a valid ZIP code' }
  validates :state, length: { is: 2 }
  validates :average_rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }, allow_nil: true
  validates :reliability_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :ssn_encrypted, presence: true, if: :onboarding_completed?

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :onboarded, -> { where(onboarding_completed: true) }
  scope :available_at, ->(datetime) {
    day_of_week = datetime.wday
    time = datetime.strftime('%H:%M:%S')
    joins(:worker_availabilities)
      .where(worker_availabilities: { day_of_week: day_of_week, is_active: true })
      .where('worker_availabilities.start_time <= ? AND worker_availabilities.end_time >= ?', time, time)
      .distinct
  }

  def full_address
    [address_line_1, address_line_2, city, state, zip_code].compact.join(', ')
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def attendance_rate
    return 0 if total_shifts_assigned.zero?
    ((total_shifts_completed.to_f / total_shifts_assigned) * 100).round(2)
  end

  def no_show_rate
    return 0 if total_shifts_assigned.zero?
    ((no_show_count.to_f / total_shifts_assigned) * 100).round(2)
  end

  def calculate_reliability_score
    # Algorithm: weighted average of attendance rate, average rating, and response time
    # Attendance: 40%, Rating: 40%, Response Time: 20%
    return 0 unless total_shifts_assigned.positive?

    attendance_score = attendance_rate * 0.4
    rating_score = (average_rating || 0) * 20 * 0.4
    response_score = if average_response_time_minutes.present?
                       [20 - (average_response_time_minutes / 10.0), 0].max
                     else
                       0
                     end

    (attendance_score + rating_score + response_score).round(2)
  end

  def update_reliability_score!
    update(reliability_score: calculate_reliability_score)
  end

  def phone_display
    PhoneNormalizationService.format_display(phone)
  end
end
