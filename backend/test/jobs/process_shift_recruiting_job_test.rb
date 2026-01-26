# frozen_string_literal: true

require "test_helper"

class ProcessShiftRecruitingJobTest < ActiveSupport::TestCase
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
      reliability_score: 80.0
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

  test "creates offer for eligible worker" do
    worker = create_eligible_worker

    ProcessShiftRecruitingJob.perform_now(@shift.id)

    assignment = ShiftAssignment.find_by(shift: @shift, worker_profile: worker)
    assert assignment.present?
    assert_equal "offered", assignment.status
  end

  test "does nothing when shift not found" do
    assert_nothing_raised do
      ProcessShiftRecruitingJob.perform_now(999999)
    end
  end

  test "does nothing when shift not recruiting" do
    @shift.update!(status: :filled)
    create_eligible_worker

    ProcessShiftRecruitingJob.perform_now(@shift.id)

    assert_equal 0, ShiftAssignment.count
  end

  test "does nothing when shift fully filled" do
    @shift.update!(slots_filled: 3)
    create_eligible_worker

    ProcessShiftRecruitingJob.perform_now(@shift.id)

    # Should not create new assignment, should mark as filled
    assert @shift.reload.filled?
  end

  test "marks shift as filled when slots_filled equals slots_total" do
    @shift.update!(slots_total: 1, slots_filled: 1)

    ProcessShiftRecruitingJob.perform_now(@shift.id)

    assert @shift.reload.filled?
  end

  test "does nothing when pending offer exists" do
    worker1 = create_eligible_worker
    create(:shift_assignment, :offered, shift: @shift, worker_profile: worker1)
    create_eligible_worker # Another eligible worker

    ProcessShiftRecruitingJob.perform_now(@shift.id)

    # Should only have the original assignment
    assert_equal 1, @shift.shift_assignments.count
  end

  test "logs recruiting_paused when no eligible workers" do
    ProcessShiftRecruitingJob.perform_now(@shift.id)

    log = RecruitingActivityLog.find_by(shift: @shift, action: "recruiting_paused")
    assert log.present?
    assert_equal "no_eligible_workers", log.details["reason"]
  end

  test "schedules timeout job for created offer" do
    create_eligible_worker

    assert_enqueued_with(job: CheckOfferTimeoutJob) do
      ProcessShiftRecruitingJob.perform_now(@shift.id)
    end
  end

  test "selects highest scored worker" do
    worker_low = create_eligible_worker(reliability_score: 30.0)
    worker_high = create_eligible_worker(reliability_score: 100.0)

    ProcessShiftRecruitingJob.perform_now(@shift.id)

    assignment = ShiftAssignment.find_by(shift: @shift)
    assert_equal worker_high.id, assignment.worker_profile_id
  end
end
