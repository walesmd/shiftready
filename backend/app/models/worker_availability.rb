# frozen_string_literal: true

class WorkerAvailability < ApplicationRecord
  # Associations
  belongs_to :worker_profile

  # Validations
  validates :day_of_week, presence: true, inclusion: { in: 0..6 }
  validates :start_time, :end_time, presence: true
  validates :day_of_week, uniqueness: {
    scope: [:worker_profile_id, :start_time, :end_time],
    message: 'availability already exists for this time range'
  }
  validate :end_time_after_start_time
  validate :no_overlapping_windows

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :for_day, ->(day) { where(day_of_week: day) }

  # Day of week helpers
  DAYS_OF_WEEK = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].freeze

  def day_name
    DAYS_OF_WEEK[day_of_week]
  end

  def time_range
    "#{start_time.strftime('%I:%M %p')} - #{end_time.strftime('%I:%M %p')}"
  end

  private

  def end_time_after_start_time
    return if end_time.blank? || start_time.blank?

    if end_time <= start_time
      errors.add(:end_time, 'must be after start time')
    end
  end

  def no_overlapping_windows
    return if worker_profile_id.blank? || day_of_week.blank? || start_time.blank? || end_time.blank?

    overlapping = WorkerAvailability
                  .where(worker_profile_id: worker_profile_id, day_of_week: day_of_week, is_active: true)
                  .where.not(id: id)
                  .where('start_time < ? AND end_time > ?', end_time, start_time)

    if overlapping.exists?
      errors.add(:base, 'This time window overlaps with an existing availability window')
    end
  end
end
