# frozen_string_literal: true

require "test_helper"

class ShiftAssignmentTest < ActiveSupport::TestCase
  # Associations
  test "belongs to shift" do
    assignment = create(:shift_assignment)
    assert assignment.shift.present?
  end

  test "belongs to worker_profile" do
    assignment = create(:shift_assignment)
    assert assignment.worker_profile.present?
  end

  test "has one payment" do
    assignment = create(:shift_assignment, :completed)
    payment = create(:payment, shift_assignment: assignment)
    assert_equal payment, assignment.payment
  end

  test "destroys associated payment when destroyed" do
    assignment = create(:shift_assignment, :completed)
    payment = create(:payment, shift_assignment: assignment)
    payment_id = payment.id

    assignment.destroy
    assert_nil Payment.find_by(id: payment_id)
  end

  # Validations
  test "requires unique worker per shift" do
    shift = create(:shift, :recruiting)
    worker = create(:worker_profile, :onboarded)
    create(:shift_assignment, shift: shift, worker_profile: worker)

    duplicate = build(:shift_assignment, shift: shift, worker_profile: worker)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:shift_id], "Worker already assigned to this shift"
  end

  test "allows same worker on different shifts" do
    worker = create(:worker_profile, :onboarded)
    shift1 = create(:shift, :recruiting)
    shift2 = create(:shift, :recruiting)

    create(:shift_assignment, shift: shift1, worker_profile: worker)
    assignment2 = build(:shift_assignment, shift: shift2, worker_profile: worker)

    assert assignment2.valid?
  end

  test "requires assigned_at" do
    # assigned_at has a NOT NULL constraint in the database AND a before_validation callback
    # that sets a default. We test the validation here.
    assignment = build(:shift_assignment)
    assignment.assigned_at = nil
    # The callback will set it, so we need to skip callbacks for this test
    assignment.define_singleton_method(:set_assigned_at_default) { nil }
    assert_not assignment.valid?
    assert_includes assignment.errors[:assigned_at], "can't be blank"
  end

  test "validates worker_rating range 1-5" do
    assignment = build(:shift_assignment, worker_rating: 6)
    assert_not assignment.valid?
    assert_includes assignment.errors[:worker_rating], "is not included in the list"
  end

  test "validates employer_rating range 1-5" do
    assignment = build(:shift_assignment, employer_rating: 0)
    assert_not assignment.valid?
    assert_includes assignment.errors[:employer_rating], "is not included in the list"
  end

  test "allows nil ratings" do
    assignment = build(:shift_assignment, worker_rating: nil, employer_rating: nil)
    assert assignment.valid?
  end

  test "validates actual_end_time after actual_start_time" do
    assignment = build(:shift_assignment,
                       actual_start_time: 1.hour.ago,
                       actual_end_time: 2.hours.ago)
    assert_not assignment.valid?
    assert_includes assignment.errors[:actual_end_time], "must be after actual start time"
  end

  # Enums
  test "status enum has correct values" do
    expected = {
      "offered" => 0,
      "accepted" => 1,
      "declined" => 2,
      "no_response" => 3,
      "confirmed" => 4,
      "checked_in" => 5,
      "no_show" => 6,
      "completed" => 7,
      "cancelled" => 8
    }
    assert_equal expected, ShiftAssignment.statuses
  end

  test "assigned_by enum has correct values" do
    expected = { "algorithm" => 0, "manual_admin" => 1, "worker_self_select" => 2 }
    assert_equal expected, ShiftAssignment.assigned_bies
  end

  test "response_method enum has correct values" do
    expected = { "sms" => 0, "app" => 1, "phone_call" => 2, "email" => 3 }
    assert_equal expected, ShiftAssignment.response_methods
  end

  test "cancelled_by enum has correct values" do
    expected = { "worker" => 0, "employer" => 1, "admin" => 2, "system" => 3 }
    assert_equal expected, ShiftAssignment.cancelled_bies
  end

  # Scopes
  test "active scope returns active assignments" do
    offered = create(:shift_assignment, :offered)
    accepted = create(:shift_assignment, :accepted)
    confirmed = create(:shift_assignment, :confirmed)
    checked_in = create(:shift_assignment, :checked_in)
    completed = create(:shift_assignment, :completed)
    cancelled = create(:shift_assignment, :cancelled)

    active = ShiftAssignment.active
    assert_includes active, offered
    assert_includes active, accepted
    assert_includes active, confirmed
    assert_includes active, checked_in
    assert_not_includes active, completed
    assert_not_includes active, cancelled
  end

  test "pending_response scope returns offered assignments" do
    offered = create(:shift_assignment, :offered)
    accepted = create(:shift_assignment, :accepted)

    assert_includes ShiftAssignment.pending_response, offered
    assert_not_includes ShiftAssignment.pending_response, accepted
  end

  test "accepted_assignments scope returns accepted and beyond" do
    offered = create(:shift_assignment, :offered)
    accepted = create(:shift_assignment, :accepted)
    confirmed = create(:shift_assignment, :confirmed)
    completed = create(:shift_assignment, :completed)
    declined = create(:shift_assignment, :declined)

    scope = ShiftAssignment.accepted_assignments
    assert_not_includes scope, offered
    assert_includes scope, accepted
    assert_includes scope, confirmed
    assert_includes scope, completed
    assert_not_includes scope, declined
  end

  test "needs_timesheet_approval returns checked_in without approval" do
    checked_in = create(:shift_assignment, :checked_in, timesheet_approved_at: nil)
    approved = create(:shift_assignment, :checked_in, timesheet_approved_at: Time.current)
    offered = create(:shift_assignment, :offered)

    scope = ShiftAssignment.needs_timesheet_approval
    assert_includes scope, checked_in
    assert_not_includes scope, approved
    assert_not_includes scope, offered
  end

  test "for_worker scope filters by worker" do
    worker1 = create(:worker_profile, :onboarded)
    worker2 = create(:worker_profile, :onboarded)
    assignment1 = create(:shift_assignment, worker_profile: worker1)
    assignment2 = create(:shift_assignment, worker_profile: worker2)

    assert_includes ShiftAssignment.for_worker(worker1.id), assignment1
    assert_not_includes ShiftAssignment.for_worker(worker1.id), assignment2
  end

  # ============================================================
  # STATE MACHINE TRANSITIONS - Core Business Logic
  # ============================================================

  # accept!
  test "accept! transitions offered assignment to accepted" do
    assignment = create(:shift_assignment, :offered)
    result = assignment.accept!

    assert result
    assert assignment.accepted?
    assert assignment.accepted_at.present?
    assert assignment.response_received_at.present?
    assert_equal "sms", assignment.response_method
    assert assignment.response_accepted?
  end

  test "accept! increments shift slots_filled" do
    shift = create(:shift, :recruiting, slots_filled: 0)
    assignment = create(:shift_assignment, :offered, shift: shift)

    assignment.accept!
    assert_equal 1, shift.reload.slots_filled
  end

  test "accept! with different response method" do
    assignment = create(:shift_assignment, :offered)
    assignment.accept!(method: :app)

    assert_equal "app", assignment.response_method
  end

  test "accept! returns false when not offered" do
    assignment = create(:shift_assignment, :accepted)
    result = assignment.accept!

    assert_not result
  end

  # decline!
  test "decline! transitions offered assignment to declined" do
    assignment = create(:shift_assignment, :offered)
    result = assignment.decline!("Schedule conflict")

    assert result
    assert assignment.declined?
    assert assignment.response_received_at.present?
    assert_equal "Schedule conflict", assignment.decline_reason
    assert assignment.response_declined?
  end

  test "decline! does not change slots_filled" do
    shift = create(:shift, :recruiting, slots_filled: 0)
    assignment = create(:shift_assignment, :offered, shift: shift)

    assignment.decline!
    assert_equal 0, shift.reload.slots_filled
  end

  test "decline! returns false when not offered" do
    assignment = create(:shift_assignment, :accepted)
    result = assignment.decline!

    assert_not result
  end

  # mark_no_response!
  test "mark_no_response! transitions offered to no_response" do
    assignment = create(:shift_assignment, :offered)
    result = assignment.mark_no_response!

    assert result
    assert assignment.no_response?
    assert assignment.response_no_response?
  end

  test "mark_no_response! returns false when not offered" do
    assignment = create(:shift_assignment, :accepted)
    result = assignment.mark_no_response!

    assert_not result
  end

  # confirm!
  test "confirm! transitions accepted assignment to confirmed" do
    assignment = create(:shift_assignment, :accepted)
    result = assignment.confirm!

    assert result
    assert assignment.confirmed?
    assert assignment.confirmed_at.present?
  end

  test "confirm! returns false when not accepted" do
    assignment = create(:shift_assignment, :offered)
    result = assignment.confirm!

    assert_not result
  end

  # check_in!
  test "check_in! transitions accepted assignment when shift has started" do
    shift = create(:shift, :recruiting, start_datetime: 1.hour.ago, end_datetime: 7.hours.from_now)
    assignment = create(:shift_assignment, :accepted, shift: shift)

    result = assignment.check_in!

    assert result
    assert assignment.checked_in?
    assert assignment.checked_in_at.present?
    assert assignment.actual_start_time.present?
  end

  test "check_in! transitions confirmed assignment when shift has started" do
    shift = create(:shift, :recruiting, start_datetime: 1.hour.ago, end_datetime: 7.hours.from_now)
    assignment = create(:shift_assignment, :confirmed, shift: shift)

    result = assignment.check_in!

    assert result
    assert assignment.checked_in?
  end

  test "check_in! records custom time" do
    shift = create(:shift, :recruiting, start_datetime: 2.hours.ago, end_datetime: 6.hours.from_now)
    assignment = create(:shift_assignment, :accepted, shift: shift)
    custom_time = 30.minutes.ago

    assignment.check_in!(custom_time)

    assert_equal custom_time.to_i, assignment.checked_in_at.to_i
    assert_equal custom_time.to_i, assignment.actual_start_time.to_i
  end

  test "check_in! returns false when shift hasn't started" do
    shift = create(:shift, :recruiting, start_datetime: 1.hour.from_now)
    assignment = create(:shift_assignment, :accepted, shift: shift)

    result = assignment.check_in!

    assert_not result
    assert assignment.accepted?
  end

  test "check_in! returns false when not accepted or confirmed" do
    assignment = create(:shift_assignment, :offered)
    result = assignment.check_in!

    assert_not result
  end

  # can_check_in?
  test "can_check_in? returns true when accepted and shift started" do
    shift = create(:shift, :recruiting, start_datetime: 1.hour.ago, end_datetime: 7.hours.from_now)
    assignment = create(:shift_assignment, :accepted, shift: shift)

    assert assignment.can_check_in?
  end

  test "can_check_in? returns true when confirmed and shift started" do
    shift = create(:shift, :recruiting, start_datetime: 1.hour.ago, end_datetime: 7.hours.from_now)
    assignment = create(:shift_assignment, :confirmed, shift: shift)

    assert assignment.can_check_in?
  end

  test "can_check_in? returns false when shift hasn't started" do
    shift = create(:shift, :recruiting, start_datetime: 1.hour.from_now)
    assignment = create(:shift_assignment, :accepted, shift: shift)

    assert_not assignment.can_check_in?
  end

  test "can_check_in? returns false when offered" do
    shift = create(:shift, :recruiting, start_datetime: 1.hour.ago, end_datetime: 7.hours.from_now)
    assignment = create(:shift_assignment, :offered, shift: shift)

    assert_not assignment.can_check_in?
  end

  # check_out!
  test "check_out! records checkout time and hours worked" do
    shift = create(:shift, :recruiting, start_datetime: 9.hours.ago, end_datetime: 1.hour.ago)
    assignment = create(:shift_assignment, :checked_in, shift: shift, actual_start_time: 8.hours.ago)

    result = assignment.check_out!

    assert result
    assert assignment.checked_out_at.present?
    assert assignment.actual_end_time.present?
    assert assignment.actual_hours_worked.present?
  end

  test "check_out! calculates hours worked correctly" do
    Timecop.freeze do
      shift = create(:shift, :recruiting)
      assignment = create(:shift_assignment, :checked_in,
                          shift: shift,
                          checked_in_at: 8.hours.ago,
                          actual_start_time: 8.hours.ago)

      assignment.check_out!

      assert_in_delta 8.0, assignment.actual_hours_worked, 0.1
    end
  end

  test "check_out! returns false when not checked in" do
    assignment = create(:shift_assignment, :accepted)
    result = assignment.check_out!

    assert_not result
  end

  # approve_timesheet!
  test "approve_timesheet! records approval" do
    assignment = create(:shift_assignment, :checked_out)
    employer = create(:employer_profile, :can_approve)

    result = assignment.approve_timesheet!(employer)

    assert result
    assert assignment.timesheet_approved_at.present?
    assert_equal employer, assignment.timesheet_approved_by_employer
  end

  test "approve_timesheet! returns false when not checked out" do
    assignment = create(:shift_assignment, :checked_in)
    employer = create(:employer_profile, :can_approve)

    result = assignment.approve_timesheet!(employer)

    assert_not result
  end

  test "approve_timesheet! returns false when already approved" do
    assignment = create(:shift_assignment, :timesheet_approved)
    employer = create(:employer_profile, :can_approve)

    result = assignment.approve_timesheet!(employer)

    assert_not result
  end

  # mark_complete!
  test "mark_complete! transitions to completed when timesheet approved" do
    assignment = create(:shift_assignment, :timesheet_approved)

    result = assignment.mark_complete!

    assert result
    assert assignment.completed?
    assert assignment.completed_successfully?
  end

  test "mark_complete! returns false without timesheet approval" do
    assignment = create(:shift_assignment, :checked_out)

    result = assignment.mark_complete!

    assert_not result
  end

  test "mark_complete! returns false without checkout" do
    assignment = create(:shift_assignment, :checked_in)

    result = assignment.mark_complete!

    assert_not result
  end

  # mark_no_show!
  test "mark_no_show! transitions offered to no_show" do
    worker = create(:worker_profile, :onboarded, no_show_count: 0)
    assignment = create(:shift_assignment, :offered, worker_profile: worker)

    result = assignment.mark_no_show!

    assert result
    assert assignment.no_show?
    assert_not assignment.completed_successfully?
    assert_equal 1, worker.reload.no_show_count
  end

  test "mark_no_show! transitions accepted to no_show and decrements slots" do
    shift = create(:shift, :recruiting, slots_filled: 1)
    worker = create(:worker_profile, :onboarded, no_show_count: 0)
    assignment = create(:shift_assignment, :accepted, shift: shift, worker_profile: worker)

    assignment.mark_no_show!

    assert assignment.no_show?
    assert_equal 0, shift.reload.slots_filled
    assert_equal 1, worker.reload.no_show_count
  end

  test "mark_no_show! transitions confirmed to no_show and decrements slots" do
    shift = create(:shift, :recruiting, slots_filled: 1)
    worker = create(:worker_profile, :onboarded, no_show_count: 0)
    assignment = create(:shift_assignment, :confirmed, shift: shift, worker_profile: worker)

    assignment.mark_no_show!

    assert assignment.no_show?
    assert_equal 0, shift.reload.slots_filled
  end

  test "mark_no_show! returns false for checked_in" do
    assignment = create(:shift_assignment, :checked_in)
    result = assignment.mark_no_show!

    assert_not result
  end

  # cancel!
  test "cancel! transitions offered to cancelled" do
    assignment = create(:shift_assignment, :offered)

    result = assignment.cancel!(by: :worker, reason: "Emergency")

    assert result
    assert assignment.cancelled?
    assert assignment.cancelled_at.present?
    assert_equal "worker", assignment.cancelled_by
    assert_equal "Emergency", assignment.cancellation_reason
  end

  test "cancel! decrements slots_filled for accepted" do
    shift = create(:shift, :recruiting, slots_filled: 1)
    assignment = create(:shift_assignment, :accepted, shift: shift)

    assignment.cancel!(by: :worker)

    assert_equal 0, shift.reload.slots_filled
  end

  test "cancel! decrements slots_filled for confirmed" do
    shift = create(:shift, :recruiting, slots_filled: 1)
    assignment = create(:shift_assignment, :confirmed, shift: shift)

    assignment.cancel!(by: :employer)

    assert_equal 0, shift.reload.slots_filled
  end

  test "cancel! decrements slots_filled for checked_in" do
    shift = create(:shift, :in_progress, slots_filled: 1)
    assignment = create(:shift_assignment, :checked_in, shift: shift)

    assignment.cancel!(by: :admin)

    assert_equal 0, shift.reload.slots_filled
  end

  test "cancel! returns false for completed" do
    assignment = create(:shift_assignment, :completed)
    result = assignment.cancel!(by: :worker)

    assert_not result
  end

  test "cancel! returns false for already cancelled" do
    assignment = create(:shift_assignment, :cancelled)
    result = assignment.cancel!(by: :worker)

    assert_not result
  end

  # ============================================================
  # QUERY METHODS
  # ============================================================

  test "checked_out? returns true when checked_out_at present" do
    assignment = build(:shift_assignment, checked_out_at: Time.current)
    assert assignment.checked_out?
  end

  test "checked_out? returns false when checked_out_at nil" do
    assignment = build(:shift_assignment, checked_out_at: nil)
    assert_not assignment.checked_out?
  end

  test "timesheet_approved? returns true when timesheet_approved_at present" do
    assignment = build(:shift_assignment, timesheet_approved_at: Time.current)
    assert assignment.timesheet_approved?
  end

  test "timesheet_approved? returns false when timesheet_approved_at nil" do
    assignment = build(:shift_assignment, timesheet_approved_at: nil)
    assert_not assignment.timesheet_approved?
  end

  test "ready_for_payment? returns true when completed with approval and no payment" do
    assignment = create(:shift_assignment, :completed)
    assert_nil assignment.payment
    assert assignment.ready_for_payment?
  end

  test "ready_for_payment? returns false when payment exists" do
    assignment = create(:shift_assignment, :completed)
    create(:payment, shift_assignment: assignment)
    assert_not assignment.ready_for_payment?
  end

  test "ready_for_payment? returns false when not completed" do
    assignment = create(:shift_assignment, :timesheet_approved)
    assert_not assignment.ready_for_payment?
  end

  # ============================================================
  # PAY CALCULATION
  # ============================================================

  test "calculated_pay_cents returns correct amount" do
    shift = create(:shift, pay_rate_cents: 1500) # $15/hr
    assignment = create(:shift_assignment, shift: shift, actual_hours_worked: 8.0)

    assert_equal 12000, assignment.calculated_pay_cents # $120
  end

  test "calculated_pay_cents returns 0 when hours missing" do
    shift = create(:shift, pay_rate_cents: 1500)
    assignment = create(:shift_assignment, shift: shift, actual_hours_worked: nil)

    assert_equal 0, assignment.calculated_pay_cents
  end

  test "formatted_calculated_pay returns formatted string" do
    shift = create(:shift, pay_rate_cents: 1500)
    assignment = create(:shift_assignment, shift: shift, actual_hours_worked: 8.0)

    assert_equal "$120.0", assignment.formatted_calculated_pay
  end

  # ============================================================
  # RESPONSE TIME TRACKING
  # ============================================================

  test "response_time_minutes calculates correctly" do
    assignment = create(:shift_assignment,
                        sms_sent_at: 30.minutes.ago,
                        response_received_at: Time.current)

    assert_equal 30, assignment.response_time_minutes
  end

  test "response_time_minutes returns nil when sms_sent_at missing" do
    assignment = create(:shift_assignment,
                        sms_sent_at: nil,
                        response_received_at: Time.current)

    assert_nil assignment.response_time_minutes
  end

  test "response_time_minutes returns nil when response_received_at missing" do
    assignment = create(:shift_assignment,
                        sms_sent_at: 30.minutes.ago,
                        response_received_at: nil)

    assert_nil assignment.response_time_minutes
  end

  # ============================================================
  # CALLBACKS - Worker stats update
  # ============================================================

  test "completing assignment updates worker stats" do
    worker = create(:worker_profile, :onboarded, total_shifts_completed: 5)
    assignment = create(:shift_assignment, :timesheet_approved, worker_profile: worker)

    assignment.mark_complete!

    assert_equal 6, worker.reload.total_shifts_completed
  end

  test "completing assignment updates reliability score" do
    worker = create(:worker_profile, :onboarded,
                    total_shifts_assigned: 10,
                    total_shifts_completed: 8,
                    average_rating: 4.0,
                    reliability_score: nil)
    assignment = create(:shift_assignment, :timesheet_approved, worker_profile: worker)

    assignment.mark_complete!

    assert worker.reload.reliability_score.present?
  end

  # ============================================================
  # DISPLAY HELPERS
  # ============================================================

  test "worker_name returns worker full name" do
    worker = create(:worker_profile, first_name: "John", last_name: "Doe")
    assignment = create(:shift_assignment, worker_profile: worker)

    assert_equal "John Doe", assignment.worker_name
  end

  test "shift_title returns shift title" do
    shift = create(:shift, title: "Warehouse Helper")
    assignment = create(:shift_assignment, shift: shift)

    assert_equal "Warehouse Helper", assignment.shift_title
  end

  test "status_display returns titleized status" do
    assignment = build(:shift_assignment, status: :checked_in)
    assert_equal "Checked In", assignment.status_display
  end
end
