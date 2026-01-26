# frozen_string_literal: true

class ShiftRecruitingDiscoveryJob < ApplicationJob
  queue_as :default

  # Recurring job that discovers posted shifts ready for recruiting
  # Runs every 5 minutes via Solid Queue recurring schedule
  def perform
    Rails.logger.info "[RecruitingDiscovery] Starting shift discovery..."

    discovered_count = 0

    shifts_ready_for_recruiting.find_each do |shift|
      begin
        discovered_count += 1 if start_recruiting_for_shift(shift)
      rescue StandardError => e
        Rails.logger.error "[RecruitingDiscovery] Error starting recruiting for shift #{shift.id}: #{e.message}"
        # Continue to next shift
      end
    end

    Rails.logger.info "[RecruitingDiscovery] Completed. Started recruiting for #{discovered_count} shifts."
  end

  private

  # Find shifts that are:
  # - status: posted
  # - start_datetime <= 7 days from now (starting within a week)
  # - start_datetime > now (still upcoming)
  # - not fully filled
  def shifts_ready_for_recruiting
    Shift.where(status: :posted)
         .where('start_datetime <= ?', 7.days.from_now)
         .where('start_datetime > ?', Time.current)
         .where('slots_filled < slots_total')
  end

  def start_recruiting_for_shift(shift)
    Rails.logger.info "[RecruitingDiscovery] Starting recruiting for shift #{shift.id} (#{shift.tracking_code})"

    # Transition shift to recruiting status
    return false unless shift.start_recruiting!

    # Log recruiting started
    RecruitingActivityLog.log_recruiting_started(
      shift,
      details: {
        discovered_at: Time.current.iso8601,
        days_until_start: ((shift.start_datetime - Time.current) / 1.day).round(1)
      }
    )

    # Enqueue the processing job
    ProcessShiftRecruitingJob.perform_later(shift.id)

    true
  end
end
