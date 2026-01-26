# frozen_string_literal: true

class ShiftOfferService
  OFFER_TIMEOUT_MINUTES = 15

  attr_reader :shift

  def initialize(shift)
    @shift = shift
  end

  # Creates an offer to the next best available worker
  # Returns the ShiftAssignment if created, nil if no eligible workers
  def create_next_offer
    return nil if shift.fully_filled?
    return nil unless shift.recruiting?

    # Check for existing pending offers
    pending_offer = shift.shift_assignments.pending_response.first
    return { status: :pending_offer_exists, assignment: pending_offer } if pending_offer

    algorithm = RecruitingAlgorithmService.new(shift)
    next_worker_result = algorithm.next_best_worker

    return nil unless next_worker_result

    worker = next_worker_result[:worker]
    score = next_worker_result[:score]
    distance = next_worker_result[:distance_miles]

    # Determine rank (how many workers have already been offered)
    rank = shift.shift_assignments.count + 1

    # Log worker selection
    RecruitingActivityLog.log_next_worker_selected(
      shift,
      worker,
      rank: rank,
      score: score
    )

    # Create the assignment
    assignment = ShiftAssignment.create!(
      shift: shift,
      worker_profile: worker,
      status: :offered,
      assigned_by: :algorithm,
      algorithm_score: score,
      distance_miles: distance,
      assigned_at: Time.current,
      sms_sent_at: Time.current # Stub: Will be set when actual SMS is sent
    )

    # Increment total_shifts_assigned on worker
    worker.increment!(:total_shifts_assigned)

    # Log the offer
    RecruitingActivityLog.log_offer_sent(shift, assignment, rank: rank)

    # Schedule timeout check
    CheckOfferTimeoutJob.set(wait: OFFER_TIMEOUT_MINUTES.minutes).perform_later(assignment.id)

    # TODO: Send actual SMS via Twilio
    # SmsService.send_shift_offer(assignment)

    assignment
  end

  # Handle worker accepting the shift offer
  def handle_acceptance(assignment)
    return false unless assignment.offered?
    return false unless assignment.shift_id == shift.id

    assignment.accept!

    # Log acceptance
    RecruitingActivityLog.log_offer_accepted(shift, assignment)

    # Check if shift is now fully filled
    if shift.reload.fully_filled?
      shift.mark_as_filled!
      RecruitingActivityLog.log_recruiting_completed(
        shift,
        reason: 'shift_fully_filled',
        details: { final_slots_filled: shift.slots_filled }
      )
    else
      # Continue recruiting for remaining slots
      ProcessShiftRecruitingJob.perform_later(shift.id)
    end

    true
  end

  # Handle worker declining the shift offer
  def handle_decline(assignment, reason: nil)
    return false unless assignment.offered?
    return false unless assignment.shift_id == shift.id

    assignment.decline!(reason)

    # Log decline
    RecruitingActivityLog.log_offer_declined(shift, assignment, reason: reason || 'not_specified')

    # Immediately queue next offer
    ProcessShiftRecruitingJob.perform_later(shift.id)

    true
  end

  # Handle offer timeout (no response within 15 minutes)
  def handle_timeout(assignment)
    return false unless assignment.offered?
    return false unless assignment.shift_id == shift.id

    assignment.mark_no_response!

    # Log timeout
    RecruitingActivityLog.log_offer_timeout(shift, assignment)

    # Queue next offer
    ProcessShiftRecruitingJob.perform_later(shift.id)

    true
  end

  # Check if there are any eligible workers remaining
  def eligible_workers_remaining?
    algorithm = RecruitingAlgorithmService.new(shift)
    algorithm.next_best_worker.present?
  end

  # Get scored workers for debugging/observability
  def ranked_workers
    algorithm = RecruitingAlgorithmService.new(shift)
    algorithm.ranked_eligible_workers
  end
end
