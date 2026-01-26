# frozen_string_literal: true

class CheckOfferTimeoutJob < ApplicationJob
  queue_as :default

  # Scheduled 15 minutes after an offer is sent
  # Marks the assignment as no_response if still in offered status
  def perform(shift_assignment_id)
    assignment = ShiftAssignment.find_by(id: shift_assignment_id)

    unless assignment
      Rails.logger.warn "[OfferTimeout] Assignment #{shift_assignment_id} not found, skipping"
      return
    end

    Rails.logger.info "[OfferTimeout] Checking timeout for assignment #{assignment.id}"

    # Only process if still in offered status
    unless assignment.offered?
      Rails.logger.info "[OfferTimeout] Assignment #{assignment.id} is no longer offered (status: #{assignment.status}), skipping"
      return
    end

    # Handle timeout
    shift = assignment.shift
    offer_service = ShiftOfferService.new(shift)

    if offer_service.handle_timeout(assignment)
      Rails.logger.info "[OfferTimeout] Marked assignment #{assignment.id} as no_response, queued next offer"
    else
      Rails.logger.error "[OfferTimeout] Failed to handle timeout for assignment #{assignment.id}"
    end
  end
end
