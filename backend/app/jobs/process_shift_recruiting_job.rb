# frozen_string_literal: true

class ProcessShiftRecruitingJob < ApplicationJob
  queue_as :default

  # Processes recruiting for a single shift
  # Creates an offer to the next best available worker
  def perform(shift_id)
    shift = Shift.find_by(id: shift_id)

    unless shift
      Rails.logger.warn "[ProcessRecruiting] Shift #{shift_id} not found, skipping"
      return
    end

    Rails.logger.info "[ProcessRecruiting] Processing shift #{shift.id} (#{shift.tracking_code})"

    # Validate shift is still in recruiting state
    unless shift.recruiting?
      Rails.logger.info "[ProcessRecruiting] Shift #{shift.id} is no longer recruiting (status: #{shift.status}), skipping"
      return
    end

    # Check if shift is fully filled
    if shift.fully_filled?
      Rails.logger.info "[ProcessRecruiting] Shift #{shift.id} is fully filled, marking as filled"
      shift.mark_as_filled!
      RecruitingActivityLog.log_recruiting_completed(shift, reason: 'shift_fully_filled')
      return
    end

    # Check if there's already a pending offer
    pending_offer = shift.shift_assignments.pending_response.first
    if pending_offer
      Rails.logger.info "[ProcessRecruiting] Shift #{shift.id} has pending offer (assignment #{pending_offer.id}), waiting"
      return
    end

    # Create next offer
    offer_service = ShiftOfferService.new(shift)
    result = offer_service.create_next_offer

    if result.nil?
      # No eligible workers remaining
      Rails.logger.info "[ProcessRecruiting] No eligible workers remaining for shift #{shift.id}"
      RecruitingActivityLog.log_recruiting_paused(
        shift,
        reason: 'no_eligible_workers',
        details: { checked_at: Time.current.iso8601 }
      )
    elsif result.is_a?(Hash) && result[:status] == :pending_offer_exists
      Rails.logger.info "[ProcessRecruiting] Pending offer already exists for shift #{shift.id}"
    else
      Rails.logger.info "[ProcessRecruiting] Created offer (assignment #{result.id}) for shift #{shift.id}"
    end
  end
end
