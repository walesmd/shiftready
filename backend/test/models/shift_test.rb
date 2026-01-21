# frozen_string_literal: true

require "test_helper"

class ShiftTest < ActiveSupport::TestCase
  # Associations
  test "belongs to company" do
    shift = create(:shift)
    assert shift.company.present?
  end

  test "belongs to work_location" do
    shift = create(:shift)
    assert shift.work_location.present?
  end

  test "belongs to created_by_employer" do
    shift = create(:shift)
    assert shift.created_by_employer.present?
    assert shift.created_by_employer.is_a?(EmployerProfile)
  end

  test "has many shift_assignments" do
    shift = create(:shift, :recruiting)
    worker_profile = create(:worker_profile, :onboarded)
    assignment = create(:shift_assignment, shift: shift, worker_profile: worker_profile)
    assert_includes shift.shift_assignments, assignment
  end

  test "has many workers through shift_assignments" do
    shift = create(:shift, :recruiting)
    worker_profile = create(:worker_profile, :onboarded)
    create(:shift_assignment, shift: shift, worker_profile: worker_profile)
    assert_includes shift.workers, worker_profile
  end

  test "destroys associated shift_assignments when destroyed" do
    shift = create(:shift, :recruiting)
    worker_profile = create(:worker_profile, :onboarded)
    assignment = create(:shift_assignment, shift: shift, worker_profile: worker_profile)
    assignment_id = assignment.id

    shift.destroy
    assert_nil ShiftAssignment.find_by(id: assignment_id)
  end

  # Validations
  test "requires title" do
    shift = build(:shift, title: nil)
    assert_not shift.valid?
    assert_includes shift.errors[:title], "can't be blank"
  end

  test "requires description" do
    shift = build(:shift, description: nil)
    assert_not shift.valid?
    assert_includes shift.errors[:description], "can't be blank"
  end

  test "requires job_type" do
    shift = build(:shift, job_type: nil)
    assert_not shift.valid?
    assert_includes shift.errors[:job_type], "can't be blank"
  end

  test "validates job_type is in allowed list" do
    shift = build(:shift, job_type: "invalid_job")
    assert_not shift.valid?
    assert_includes shift.errors[:job_type], "is not included in the list"
  end

  test "accepts valid job_type" do
    WorkerPreferredJobType::AVAILABLE_JOB_TYPES.each do |job_type|
      shift = build(:shift, job_type: job_type)
      assert shift.valid?, "#{job_type} should be a valid job type"
    end
  end

  test "requires start_datetime" do
    shift = build(:shift, start_datetime: nil)
    assert_not shift.valid?
    assert_includes shift.errors[:start_datetime], "can't be blank"
  end

  test "requires end_datetime" do
    shift = build(:shift, end_datetime: nil)
    assert_not shift.valid?
    assert_includes shift.errors[:end_datetime], "can't be blank"
  end

  test "requires pay_rate_cents" do
    shift = build(:shift, pay_rate_cents: nil)
    assert_not shift.valid?
    assert_includes shift.errors[:pay_rate_cents], "can't be blank"
  end

  test "requires pay_rate_cents to be positive" do
    shift = build(:shift, pay_rate_cents: 0)
    assert_not shift.valid?
    assert_includes shift.errors[:pay_rate_cents], "must be greater than 0"
  end

  test "requires slots_total to be non-negative" do
    shift = build(:shift, slots_total: -1)
    assert_not shift.valid?
    assert_includes shift.errors[:slots_total], "must be greater than or equal to 0"
  end

  test "requires slots_filled to be non-negative" do
    shift = build(:shift, slots_filled: -1)
    assert_not shift.valid?
    assert_includes shift.errors[:slots_filled], "must be greater than or equal to 0"
  end

  test "end_datetime must be after start_datetime" do
    shift = build(:shift,
                  start_datetime: 1.day.from_now.change(hour: 16),
                  end_datetime: 1.day.from_now.change(hour: 8))
    assert_not shift.valid?
    assert_includes shift.errors[:end_datetime], "must be after start datetime"
  end

  test "min_workers_needed cannot exceed slots_total" do
    shift = build(:shift, slots_total: 3, min_workers_needed: 5)
    assert_not shift.valid?
    assert_includes shift.errors[:min_workers_needed], "cannot be greater than total slots"
  end

  # Enums
  test "status enum has correct values" do
    expected = {
      "draft" => 0,
      "posted" => 1,
      "recruiting" => 2,
      "filled" => 3,
      "in_progress" => 4,
      "completed" => 5,
      "cancelled" => 6
    }
    assert_equal expected, Shift.statuses
  end

  # Scopes
  test "active scope excludes cancelled and completed shifts" do
    active = create(:shift, :recruiting)
    cancelled = create(:shift, :cancelled)
    completed = create(:shift, :completed)

    assert_includes Shift.active, active
    assert_not_includes Shift.active, cancelled
    assert_not_includes Shift.active, completed
  end

  test "recruiting scope returns only recruiting shifts" do
    recruiting = create(:shift, :recruiting)
    draft = create(:shift, status: :draft)

    assert_includes Shift.recruiting, recruiting
    assert_not_includes Shift.recruiting, draft
  end

  test "upcoming scope returns future shifts" do
    upcoming = create(:shift, start_datetime: 2.days.from_now, end_datetime: 2.days.from_now + 8.hours)
    past = create(:shift, start_datetime: 2.days.ago.change(hour: 8), end_datetime: 2.days.ago.change(hour: 16))

    assert_includes Shift.upcoming, upcoming
    assert_not_includes Shift.upcoming, past
  end

  test "past scope returns past shifts" do
    upcoming = create(:shift, start_datetime: 2.days.from_now, end_datetime: 2.days.from_now + 8.hours)
    past = create(:shift, :past)

    assert_includes Shift.past, past
    assert_not_includes Shift.past, upcoming
  end

  test "for_job_type scope filters by job type" do
    warehouse = create(:shift, job_type: "warehouse")
    moving = create(:shift, job_type: "moving")

    assert_includes Shift.for_job_type("warehouse"), warehouse
    assert_not_includes Shift.for_job_type("warehouse"), moving
  end

  test "for_company scope filters by company" do
    company1 = create(:company)
    company2 = create(:company)
    shift1 = create(:shift, company: company1)
    shift2 = create(:shift, company: company2)

    assert_includes Shift.for_company(company1.id), shift1
    assert_not_includes Shift.for_company(company1.id), shift2
  end

  test "needs_workers scope returns shifts with available slots" do
    needs_workers = create(:shift, slots_total: 5, slots_filled: 3)
    full = create(:shift, slots_total: 5, slots_filled: 5)

    assert_includes Shift.needs_workers, needs_workers
    assert_not_includes Shift.needs_workers, full
  end

  # Instance methods - Calculations
  test "hourly_rate returns rate in dollars" do
    shift = build(:shift, pay_rate_cents: 1500)
    assert_equal 15.0, shift.hourly_rate
  end

  test "formatted_pay_rate returns formatted string" do
    shift = build(:shift, pay_rate_cents: 1500)
    assert_equal "$15.0/hr", shift.formatted_pay_rate
  end

  test "duration_hours calculates correct duration" do
    shift = build(:shift,
                  start_datetime: 1.day.from_now.change(hour: 8),
                  end_datetime: 1.day.from_now.change(hour: 16))
    assert_equal 8.0, shift.duration_hours
  end

  test "duration_hours returns 0 for missing datetimes" do
    shift = build(:shift, start_datetime: nil, end_datetime: nil)
    assert_equal 0, shift.duration_hours
  end

  test "estimated_pay calculates correctly" do
    shift = build(:shift,
                  pay_rate_cents: 1500,
                  start_datetime: 1.day.from_now.change(hour: 8),
                  end_datetime: 1.day.from_now.change(hour: 16))
    assert_equal 120.0, shift.estimated_pay # $15 * 8 hours
  end

  test "formatted_estimated_pay returns formatted string" do
    shift = build(:shift,
                  pay_rate_cents: 1500,
                  start_datetime: 1.day.from_now.change(hour: 8),
                  end_datetime: 1.day.from_now.change(hour: 16))
    assert_equal "$120.0", shift.formatted_estimated_pay
  end

  # Slots management
  test "slots_available calculates correctly" do
    shift = build(:shift, slots_total: 5, slots_filled: 3)
    assert_equal 2, shift.slots_available
  end

  test "fully_filled? returns true when all slots filled" do
    shift = build(:shift, slots_total: 5, slots_filled: 5)
    assert shift.fully_filled?
  end

  test "fully_filled? returns true when overfilled" do
    shift = build(:shift, slots_total: 5, slots_filled: 6)
    assert shift.fully_filled?
  end

  test "fully_filled? returns false when slots available" do
    shift = build(:shift, slots_total: 5, slots_filled: 3)
    assert_not shift.fully_filled?
  end

  # Temporal helpers
  test "upcoming? returns true for future shifts" do
    shift = build(:shift, start_datetime: 1.day.from_now)
    assert shift.upcoming?
  end

  test "upcoming? returns false for past shifts" do
    shift = build(:shift, start_datetime: 1.day.ago)
    assert_not shift.upcoming?
  end

  test "in_past? returns true for past shifts" do
    shift = build(:shift, start_datetime: 1.day.ago)
    assert shift.in_past?
  end

  test "in_past? returns false for future shifts" do
    shift = build(:shift, start_datetime: 1.day.from_now)
    assert_not shift.in_past?
  end

  # Status transitions - can_start_recruiting?
  test "can_start_recruiting? returns true when posted and not filled and upcoming" do
    shift = create(:shift, :posted, slots_total: 5, slots_filled: 0, start_datetime: 1.day.from_now, end_datetime: 1.day.from_now + 8.hours)
    assert shift.can_start_recruiting?
  end

  test "can_start_recruiting? returns false when not posted" do
    shift = create(:shift, status: :draft)
    assert_not shift.can_start_recruiting?
  end

  test "can_start_recruiting? returns false when fully filled" do
    shift = create(:shift, :posted, slots_total: 5, slots_filled: 5)
    assert_not shift.can_start_recruiting?
  end

  test "can_start_recruiting? returns false for past shifts" do
    shift = create(:shift, :posted, :past)
    assert_not shift.can_start_recruiting?
  end

  # start_recruiting!
  test "start_recruiting! transitions to recruiting status" do
    shift = create(:shift, :posted, start_datetime: 1.day.from_now, end_datetime: 1.day.from_now + 8.hours)
    result = shift.start_recruiting!

    assert result
    assert shift.recruiting?
    assert shift.recruiting_started_at.present?
  end

  test "start_recruiting! returns false when conditions not met" do
    shift = create(:shift, status: :draft)
    result = shift.start_recruiting!

    assert_not result
    assert shift.draft?
  end

  # mark_as_filled!
  test "mark_as_filled! transitions to filled status" do
    shift = create(:shift, :recruiting, slots_total: 5, slots_filled: 5)
    result = shift.mark_as_filled!

    assert result
    assert shift.filled?
    assert shift.filled_at.present?
  end

  test "mark_as_filled! returns false when not fully filled" do
    shift = create(:shift, :recruiting, slots_total: 5, slots_filled: 3)
    result = shift.mark_as_filled!

    assert_not result
    assert shift.recruiting?
  end

  # cancel!
  test "cancel! transitions to cancelled status" do
    shift = create(:shift, :recruiting)
    shift.cancel!("Business needs changed")

    assert shift.cancelled?
    assert shift.cancelled_at.present?
    assert_equal "Business needs changed", shift.cancellation_reason
  end

  # start!
  test "start! transitions filled shift to in_progress" do
    shift = create(:shift, :filled, start_datetime: 1.hour.ago, end_datetime: 7.hours.from_now)
    result = shift.start!

    assert result
    assert shift.in_progress?
  end

  test "start! returns false when not filled" do
    shift = create(:shift, :recruiting, start_datetime: 1.hour.ago)
    result = shift.start!

    assert_not result
    assert shift.recruiting?
  end

  test "start! returns false when start time is in future" do
    shift = create(:shift, :filled)
    result = shift.start!

    assert_not result
    assert shift.filled?
  end

  # complete!
  test "complete! transitions in_progress shift to completed" do
    shift = create(:shift, :in_progress, start_datetime: 9.hours.ago, end_datetime: 1.hour.ago)
    result = shift.complete!

    assert result
    assert shift.completed?
    assert shift.completed_at.present?
  end

  test "complete! returns false when not in_progress" do
    shift = create(:shift, :filled, start_datetime: 9.hours.ago, end_datetime: 1.hour.ago)
    result = shift.complete!

    assert_not result
    assert shift.filled?
  end

  test "complete! returns false when end time is in future" do
    shift = create(:shift, :in_progress)
    result = shift.complete!

    assert_not result
    assert shift.in_progress?
  end

  # formatted_datetime_range
  test "formatted_datetime_range formats same-day shifts" do
    shift = build(:shift,
                  start_datetime: Time.zone.local(2025, 3, 15, 8, 0),
                  end_datetime: Time.zone.local(2025, 3, 15, 16, 0))

    assert_equal "Mar 15, 2025 from 08:00 AM to 04:00 PM", shift.formatted_datetime_range
  end

  test "formatted_datetime_range formats multi-day shifts" do
    shift = build(:shift,
                  start_datetime: Time.zone.local(2025, 3, 15, 20, 0),
                  end_datetime: Time.zone.local(2025, 3, 16, 4, 0))

    assert_equal "Mar 15, 08:00 PM - Mar 16, 04:00 AM", shift.formatted_datetime_range
  end

  test "formatted_datetime_range returns empty for missing times" do
    shift = build(:shift, start_datetime: nil, end_datetime: nil)
    assert_equal "", shift.formatted_datetime_range
  end

  # can_be_deleted?
  test "can_be_deleted? returns true for draft shifts" do
    shift = create(:shift, status: :draft)
    assert shift.can_be_deleted?
  end

  test "can_be_deleted? returns true when no accepted assignments" do
    shift = create(:shift, :recruiting)
    worker = create(:worker_profile, :onboarded)
    create(:shift_assignment, :declined, shift: shift, worker_profile: worker)

    assert shift.can_be_deleted?
  end

  test "can_be_deleted? returns false when has accepted assignments" do
    shift = create(:shift, :recruiting)
    worker = create(:worker_profile, :onboarded)
    create(:shift_assignment, :accepted, shift: shift, worker_profile: worker)

    assert_not shift.can_be_deleted?
  end

  # Default values
  test "sets min_workers_needed to 1 by default" do
    shift = build(:shift, min_workers_needed: nil)
    shift.valid?
    assert_equal 1, shift.min_workers_needed
  end

  # Auto-fill callback
  test "auto-transitions to filled when slots_filled reaches slots_total" do
    shift = create(:shift, :recruiting, slots_total: 2, slots_filled: 1)
    shift.update!(slots_filled: 2)

    assert shift.reload.filled?
    assert shift.filled_at.present?
  end

  test "auto-transitions to filled for posted shift" do
    shift = create(:shift, :posted, slots_total: 1, slots_filled: 0)
    shift.update!(slots_filled: 1)

    assert shift.reload.filled?
  end

  test "does not auto-transition when already filled status" do
    shift = create(:shift, :filled, slots_total: 2, slots_filled: 2, filled_at: 1.day.ago)
    original_filled_at = shift.filled_at

    shift.update!(slots_filled: 3) # Edge case of overfilling

    assert_equal original_filled_at, shift.reload.filled_at
  end
end
