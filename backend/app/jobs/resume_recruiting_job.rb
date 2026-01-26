# frozen_string_literal: true

class ResumeRecruitingJob < ApplicationJob
  queue_as :default

  # Called when a shift assignment is cancelled
  # Resumes recruiting if the shift is still valid for recruiting
  def perform(shift_id)
    shift = Shift.find_by(id: shift_id)

    unless shift
      Rails.logger.warn "[ResumeRecruiting] Shift #{shift_id} not found, skipping"
      return
    end

    Rails.logger.info "[ResumeRecruiting] Checking if recruiting can resume for shift #{shift.id} (#{shift.tracking_code})"
    previous_status = shift.status

    # Validate conditions for resuming
    unless can_resume?(shift)
      Rails.logger.info "[ResumeRecruiting] Cannot resume recruiting for shift #{shift.id}"
      return
    end

    # Transition back to recruiting if needed
    if shift.filled?
      shift.update!(status: :recruiting)
      Rails.logger.info "[ResumeRecruiting] Transitioned shift #{shift.id} from filled to recruiting"
    end

    # Log recruiting resumed
    RecruitingActivityLog.log_recruiting_resumed(
      shift,
      details: {
        resumed_at: Time.current.iso8601,
        previous_status: previous_status,
        hours_until_start: ((shift.start_datetime - Time.current) / 1.hour).round(1)
      }
    )

    # Enqueue processing job
    ProcessShiftRecruitingJob.perform_later(shift.id)
  end

  private

  def can_resume?(shift)
    # Must be more than 24 hours away
    unless shift.start_datetime > 24.hours.from_now
      Rails.logger.info "[ResumeRecruiting] Shift #{shift.id} starts within 24 hours, cannot resume"
      return false
    end

    # Must not be fully filled
    if shift.fully_filled?
      Rails.logger.info "[ResumeRecruiting] Shift #{shift.id} is fully filled, no need to resume"
      return false
    end

    # Must be in a state that can resume
    unless shift.filled? || shift.recruiting?
      Rails.logger.info "[ResumeRecruiting] Shift #{shift.id} is in #{shift.status} status, cannot resume"
      return false
    end

    true
  end
end
