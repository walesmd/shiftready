# frozen_string_literal: true

require "test_helper"

class ShiftOfferServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @company = create(:company)
    @work_location = create(:work_location, company: @company, latitude: 29.4241, longitude: -98.4936)
    @employer = create(:employer_profile, :onboarded, company: @company)
    @shift = create(:shift, :recruiting,
                    company: @company,
                    work_location: @work_location,
                    created_by_employer: @employer,
                    job_type: "warehouse",
                    slots_total: 3,
                    slots_filled: 0,
                    start_datetime: 2.days.from_now.change(hour: 8),
                    end_datetime: 2.days.from_now.change(hour: 16))
  end

  def create_eligible_worker(attributes = {})
    worker = create(:worker_profile, :onboarded, {
      latitude: 29.4341,
      longitude: -98.5036,
      reliability_score: 80.0,
      average_rating: 4.5,
      average_response_time_minutes: 10,
      total_shifts_completed: 10
    }.merge(attributes))

    create(:worker_preferred_job_type, worker_profile: worker, job_type: "warehouse")

    day_of_week = @shift.start_datetime.wday
    create(:worker_availability,
           worker_profile: worker,
           day_of_week: day_of_week,
           start_time: "06:00",
           end_time: "18:00")

    worker
  end

  # create_next_offer tests
  test "create_next_offer creates assignment for best worker" do
    worker = create_eligible_worker

    service = ShiftOfferService.new(@shift)
    assignment = service.create_next_offer

    assert assignment.is_a?(ShiftAssignment)
    assert_equal worker, assignment.worker_profile
    assert_equal @shift, assignment.shift
    assert_equal "offered", assignment.status
    assert_equal "algorithm", assignment.assigned_by
    assert assignment.algorithm_score.present?
    assert assignment.distance_miles.present?
    assert assignment.sms_sent_at.present?
  end

  test "create_next_offer increments worker total_shifts_assigned" do
    worker = create_eligible_worker
    original_count = worker.total_shifts_assigned

    service = ShiftOfferService.new(@shift)
    service.create_next_offer

    assert_equal original_count + 1, worker.reload.total_shifts_assigned
  end

  test "create_next_offer logs offer_sent" do
    create_eligible_worker

    service = ShiftOfferService.new(@shift)
    service.create_next_offer

    log = RecruitingActivityLog.find_by(shift: @shift, action: "offer_sent")
    assert log.present?
    assert_equal 1, log.details["rank"]
  end

  test "create_next_offer schedules timeout job" do
    create_eligible_worker

    service = ShiftOfferService.new(@shift)

    assert_enqueued_with(job: CheckOfferTimeoutJob) do
      service.create_next_offer
    end
  end

  test "create_next_offer returns nil when shift is fully filled" do
    @shift.update!(slots_filled: 3) # Fully filled

    service = ShiftOfferService.new(@shift)
    result = service.create_next_offer

    assert_nil result
  end

  test "create_next_offer returns nil when shift is not recruiting" do
    @shift.update!(status: :filled)

    service = ShiftOfferService.new(@shift)
    result = service.create_next_offer

    assert_nil result
  end

  test "create_next_offer returns nil when pending offer exists" do
    worker = create_eligible_worker
    create(:shift_assignment, :offered, shift: @shift, worker_profile: worker)

    create_eligible_worker # Another eligible worker

    service = ShiftOfferService.new(@shift)
    result = service.create_next_offer

    assert_nil result
  end

  test "create_next_offer returns nil when no eligible workers" do
    # No workers created

    service = ShiftOfferService.new(@shift)
    result = service.create_next_offer

    assert_nil result
  end

  test "create_next_offer logs next_worker_selected" do
    create_eligible_worker

    service = ShiftOfferService.new(@shift)
    service.create_next_offer

    log = RecruitingActivityLog.find_by(shift: @shift, action: "next_worker_selected")
    assert log.present?
  end

  # handle_acceptance tests
  test "handle_acceptance accepts the assignment" do
    worker = create_eligible_worker
    assignment = create(:shift_assignment, :offered, shift: @shift, worker_profile: worker)

    service = ShiftOfferService.new(@shift)
    result = service.handle_acceptance(assignment)

    assert result
    assert assignment.reload.accepted?
  end

  test "handle_acceptance logs offer_accepted" do
    worker = create_eligible_worker
    assignment = create(:shift_assignment, :offered, shift: @shift, worker_profile: worker, sms_sent_at: 5.minutes.ago)

    service = ShiftOfferService.new(@shift)
    service.handle_acceptance(assignment)

    log = RecruitingActivityLog.find_by(shift: @shift, action: "offer_accepted")
    assert log.present?
    assert_equal assignment.id, log.shift_assignment_id
  end

  test "handle_acceptance marks shift filled when all slots filled" do
    @shift.update!(slots_total: 1, slots_filled: 0)
    worker = create_eligible_worker
    assignment = create(:shift_assignment, :offered, shift: @shift, worker_profile: worker)

    service = ShiftOfferService.new(@shift)
    service.handle_acceptance(assignment)

    assert @shift.reload.filled?
  end

  test "handle_acceptance logs recruiting_completed when shift filled" do
    @shift.update!(slots_total: 1, slots_filled: 0)
    worker = create_eligible_worker
    assignment = create(:shift_assignment, :offered, shift: @shift, worker_profile: worker)

    service = ShiftOfferService.new(@shift)
    service.handle_acceptance(assignment)

    log = RecruitingActivityLog.find_by(shift: @shift, action: "recruiting_completed")
    assert log.present?
    assert_equal "shift_fully_filled", log.details["reason"]
  end

  test "handle_acceptance continues recruiting when slots remain" do
    worker = create_eligible_worker
    assignment = create(:shift_assignment, :offered, shift: @shift, worker_profile: worker)

    service = ShiftOfferService.new(@shift)

    assert_enqueued_with(job: ProcessShiftRecruitingJob) do
      service.handle_acceptance(assignment)
    end
  end

  test "handle_acceptance returns false for non-offered assignment" do
    worker = create_eligible_worker
    assignment = create(:shift_assignment, :accepted, shift: @shift, worker_profile: worker)

    service = ShiftOfferService.new(@shift)
    result = service.handle_acceptance(assignment)

    assert_not result
  end

  test "handle_acceptance returns false for wrong shift" do
    other_shift = create(:shift, :recruiting, company: @company, work_location: @work_location)
    worker = create_eligible_worker
    assignment = create(:shift_assignment, :offered, shift: other_shift, worker_profile: worker)

    service = ShiftOfferService.new(@shift)
    result = service.handle_acceptance(assignment)

    assert_not result
  end

  # handle_decline tests
  test "handle_decline declines the assignment" do
    worker = create_eligible_worker
    assignment = create(:shift_assignment, :offered, shift: @shift, worker_profile: worker)

    service = ShiftOfferService.new(@shift)
    result = service.handle_decline(assignment, reason: "schedule_conflict")

    assert result
    assert assignment.reload.declined?
  end

  test "handle_decline logs offer_declined" do
    worker = create_eligible_worker
    assignment = create(:shift_assignment, :offered, shift: @shift, worker_profile: worker, sms_sent_at: 5.minutes.ago)

    service = ShiftOfferService.new(@shift)
    service.handle_decline(assignment, reason: "schedule_conflict")

    log = RecruitingActivityLog.find_by(shift: @shift, action: "offer_declined")
    assert log.present?
    assert_equal "schedule_conflict", log.details["reason"]
  end

  test "handle_decline queues next offer" do
    worker = create_eligible_worker
    assignment = create(:shift_assignment, :offered, shift: @shift, worker_profile: worker)

    service = ShiftOfferService.new(@shift)

    assert_enqueued_with(job: ProcessShiftRecruitingJob) do
      service.handle_decline(assignment)
    end
  end

  test "handle_decline returns false for non-offered assignment" do
    worker = create_eligible_worker
    assignment = create(:shift_assignment, :accepted, shift: @shift, worker_profile: worker)

    service = ShiftOfferService.new(@shift)
    result = service.handle_decline(assignment)

    assert_not result
  end

  # handle_timeout tests
  test "handle_timeout marks no_response" do
    worker = create_eligible_worker
    assignment = create(:shift_assignment, :offered, shift: @shift, worker_profile: worker, sms_sent_at: 15.minutes.ago)

    service = ShiftOfferService.new(@shift)
    result = service.handle_timeout(assignment)

    assert result
    assert assignment.reload.no_response?
  end

  test "handle_timeout logs offer_timeout" do
    worker = create_eligible_worker
    assignment = create(:shift_assignment, :offered, shift: @shift, worker_profile: worker, sms_sent_at: 15.minutes.ago)

    service = ShiftOfferService.new(@shift)
    service.handle_timeout(assignment)

    log = RecruitingActivityLog.find_by(shift: @shift, action: "offer_timeout")
    assert log.present?
    assert_equal 15, log.details["timeout_minutes"]
  end

  test "handle_timeout queues next offer" do
    worker = create_eligible_worker
    assignment = create(:shift_assignment, :offered, shift: @shift, worker_profile: worker)

    service = ShiftOfferService.new(@shift)

    assert_enqueued_with(job: ProcessShiftRecruitingJob) do
      service.handle_timeout(assignment)
    end
  end

  test "handle_timeout returns false for already timed out assignment" do
    worker = create_eligible_worker
    # Create an assignment that's already been marked as no_response
    assignment = create(:shift_assignment, shift: @shift, worker_profile: worker, status: :no_response, response_value: :no_response)

    service = ShiftOfferService.new(@shift)
    result = service.handle_timeout(assignment)

    assert_not result
  end

  # Helper method tests
  test "eligible_workers_remaining? returns true when workers available" do
    create_eligible_worker

    service = ShiftOfferService.new(@shift)
    assert service.eligible_workers_remaining?
  end

  test "eligible_workers_remaining? returns false when no workers available" do
    service = ShiftOfferService.new(@shift)
    assert_not service.eligible_workers_remaining?
  end

  test "ranked_workers returns scored list" do
    create_eligible_worker
    create_eligible_worker

    service = ShiftOfferService.new(@shift)
    ranked = service.ranked_workers

    assert_equal 2, ranked.length
    assert ranked.first[:score] >= ranked.last[:score]
  end
end
