# frozen_string_literal: true

require "test_helper"

class RecruitingActivityLogTest < ActiveSupport::TestCase
  # Associations
  test "belongs to shift" do
    log = create(:recruiting_activity_log)
    assert log.shift.present?
  end

  test "belongs to worker_profile optionally" do
    log = create(:recruiting_activity_log)
    assert_nil log.worker_profile

    log_with_worker = create(:recruiting_activity_log, :with_worker)
    assert log_with_worker.worker_profile.present?
  end

  test "belongs to shift_assignment optionally" do
    log = create(:recruiting_activity_log)
    assert_nil log.shift_assignment

    log_with_assignment = create(:recruiting_activity_log, :with_assignment)
    assert log_with_assignment.shift_assignment.present?
  end

  # Validations
  test "requires action" do
    log = build(:recruiting_activity_log, action: nil)
    assert_not log.valid?
    assert_includes log.errors[:action], "can't be blank"
  end

  test "validates action is in allowed list" do
    log = build(:recruiting_activity_log, action: "invalid_action")
    assert_not log.valid?
    assert_includes log.errors[:action], "is not included in the list"
  end

  test "accepts all valid actions" do
    RecruitingActivityLog::ACTIONS.each do |action|
      log = build(:recruiting_activity_log, action: action)
      assert log.valid?, "#{action} should be a valid action"
    end
  end

  test "requires source" do
    log = build(:recruiting_activity_log, source: nil)
    assert_not log.valid?
    assert_includes log.errors[:source], "can't be blank"
  end

  test "validates source is in allowed list" do
    log = build(:recruiting_activity_log, source: "invalid_source")
    assert_not log.valid?
    assert_includes log.errors[:source], "is not included in the list"
  end

  test "accepts all valid sources" do
    RecruitingActivityLog::SOURCES.each do |source|
      log = build(:recruiting_activity_log, source: source)
      assert log.valid?, "#{source} should be a valid source"
    end
  end

  # Scopes
  test "for_shift scope filters by shift" do
    shift1 = create(:shift, :recruiting)
    shift2 = create(:shift, :recruiting)
    log1 = create(:recruiting_activity_log, shift: shift1)
    log2 = create(:recruiting_activity_log, shift: shift2)

    assert_includes RecruitingActivityLog.for_shift(shift1.id), log1
    assert_not_includes RecruitingActivityLog.for_shift(shift1.id), log2
  end

  test "for_worker scope filters by worker" do
    worker = create(:worker_profile, :onboarded)
    log1 = create(:recruiting_activity_log, :with_worker, worker_profile: worker)
    log2 = create(:recruiting_activity_log, :with_worker)

    assert_includes RecruitingActivityLog.for_worker(worker.id), log1
    assert_not_includes RecruitingActivityLog.for_worker(worker.id), log2
  end

  test "by_action scope filters by action" do
    log1 = create(:recruiting_activity_log, :recruiting_started)
    log2 = create(:recruiting_activity_log, :offer_sent)

    assert_includes RecruitingActivityLog.by_action("recruiting_started"), log1
    assert_not_includes RecruitingActivityLog.by_action("recruiting_started"), log2
  end

  test "chronological scope orders by created_at ascending" do
    log1 = create(:recruiting_activity_log)
    log2 = create(:recruiting_activity_log)

    logs = RecruitingActivityLog.chronological
    assert_equal [log1.id, log2.id], logs.pluck(:id)
  end

  test "recent scope orders by created_at descending" do
    log1 = create(:recruiting_activity_log)
    log2 = create(:recruiting_activity_log)

    logs = RecruitingActivityLog.recent
    assert_equal [log2.id, log1.id], logs.pluck(:id)
  end

  # Class methods for logging
  test "log_recruiting_started creates log with correct data" do
    shift = create(:shift, :recruiting, slots_total: 5, slots_filled: 0)

    log = RecruitingActivityLog.log_recruiting_started(shift)

    assert_equal shift, log.shift
    assert_equal "recruiting_started", log.action
    assert_equal "algorithm", log.source
    assert_equal 5, log.details["slots_total"]
    assert_equal 0, log.details["slots_filled"]
    assert log.details["start_datetime"].present?
  end

  test "log_recruiting_paused creates log with reason" do
    shift = create(:shift, :recruiting)

    log = RecruitingActivityLog.log_recruiting_paused(shift, reason: "no_eligible_workers")

    assert_equal "recruiting_paused", log.action
    assert_equal "no_eligible_workers", log.details["reason"]
  end

  test "log_recruiting_resumed creates log with details" do
    shift = create(:shift, :recruiting, slots_total: 5, slots_filled: 2)

    log = RecruitingActivityLog.log_recruiting_resumed(shift)

    assert_equal "recruiting_resumed", log.action
    assert_equal 3, log.details["slots_available"]
  end

  test "log_recruiting_completed creates log with reason" do
    shift = create(:shift, :recruiting, slots_total: 5, slots_filled: 5)

    log = RecruitingActivityLog.log_recruiting_completed(shift, reason: "shift_fully_filled")

    assert_equal "recruiting_completed", log.action
    assert_equal "shift_fully_filled", log.details["reason"]
    assert_equal 5, log.details["slots_filled"]
    assert_equal 5, log.details["slots_total"]
  end

  test "log_worker_scored creates log with score breakdown" do
    shift = create(:shift, :recruiting)
    worker = create(:worker_profile, :onboarded)
    score_breakdown = { distance: 30, reliability: 20, job_type: 15, rating: 10, response_time: 5, experience: 5 }

    log = RecruitingActivityLog.log_worker_scored(shift, worker, score: 85.0, score_breakdown: score_breakdown)

    assert_equal "worker_scored", log.action
    assert_equal worker, log.worker_profile
    assert_equal 85.0, log.details["score"]
    assert_equal score_breakdown.stringify_keys, log.details["score_breakdown"]
  end

  test "log_worker_excluded creates log with reason" do
    shift = create(:shift, :recruiting)
    worker = create(:worker_profile, :onboarded)

    log = RecruitingActivityLog.log_worker_excluded(shift, worker, reason: "distance_too_far")

    assert_equal "worker_excluded", log.action
    assert_equal worker, log.worker_profile
    assert_equal "distance_too_far", log.details["reason"]
  end

  test "log_offer_sent creates log with assignment data" do
    shift = create(:shift, :recruiting)
    worker = create(:worker_profile, :onboarded)
    assignment = create(:shift_assignment, :offered, shift: shift, worker_profile: worker, algorithm_score: 85.5, distance_miles: 3.5)

    log = RecruitingActivityLog.log_offer_sent(shift, assignment, rank: 1)

    assert_equal "offer_sent", log.action
    assert_equal worker, log.worker_profile
    assert_equal assignment, log.shift_assignment
    assert_equal 1, log.details["rank"]
    assert_equal 85.5, log.details["algorithm_score"].to_f
    assert_equal 3.5, log.details["distance_miles"].to_f
  end

  test "log_offer_accepted creates log with response time" do
    shift = create(:shift, :recruiting, slots_total: 5, slots_filled: 0)
    worker = create(:worker_profile, :onboarded)
    assignment = create(:shift_assignment, :accepted, shift: shift, worker_profile: worker, sms_sent_at: 5.minutes.ago, response_received_at: Time.current)

    log = RecruitingActivityLog.log_offer_accepted(shift, assignment)

    assert_equal "offer_accepted", log.action
    assert_equal worker, log.worker_profile
    assert_equal assignment, log.shift_assignment
    assert log.details["response_time_minutes"].present?
  end

  test "log_offer_declined creates log with reason" do
    shift = create(:shift, :recruiting)
    worker = create(:worker_profile, :onboarded)
    assignment = create(:shift_assignment, :declined, shift: shift, worker_profile: worker, sms_sent_at: 10.minutes.ago)

    log = RecruitingActivityLog.log_offer_declined(shift, assignment, reason: "schedule_conflict")

    assert_equal "offer_declined", log.action
    assert_equal "schedule_conflict", log.details["reason"]
  end

  test "log_offer_timeout creates log with timeout info" do
    shift = create(:shift, :recruiting)
    worker = create(:worker_profile, :onboarded)
    assignment = create(:shift_assignment, :offered, shift: shift, worker_profile: worker, sms_sent_at: 15.minutes.ago)

    log = RecruitingActivityLog.log_offer_timeout(shift, assignment)

    assert_equal "offer_timeout", log.action
    assert_equal 15, log.details["timeout_minutes"]
    assert log.details["offer_sent_at"].present?
  end

  test "log_next_worker_selected creates log with rank and score" do
    shift = create(:shift, :recruiting)
    worker = create(:worker_profile, :onboarded)

    log = RecruitingActivityLog.log_next_worker_selected(shift, worker, rank: 3, score: 75.5)

    assert_equal "next_worker_selected", log.action
    assert_equal worker, log.worker_profile
    assert_equal 3, log.details["rank"]
    assert_equal 75.5, log.details["score"]
  end

  # Association destruction behavior
  test "destroying shift destroys associated logs" do
    shift = create(:shift, :recruiting)
    log = create(:recruiting_activity_log, shift: shift)
    log_id = log.id

    shift.destroy
    assert_nil RecruitingActivityLog.find_by(id: log_id)
  end

  test "destroying worker nullifies worker_profile_id" do
    worker = create(:worker_profile, :onboarded)
    log = create(:recruiting_activity_log, :with_worker, worker_profile: worker)

    worker.destroy
    log.reload
    assert_nil log.worker_profile_id
  end

  test "destroying shift_assignment nullifies shift_assignment_id" do
    shift = create(:shift, :recruiting)
    worker = create(:worker_profile, :onboarded)
    assignment = create(:shift_assignment, shift: shift, worker_profile: worker)
    log = create(:recruiting_activity_log, shift: shift, worker_profile: worker, shift_assignment: assignment)

    assignment.destroy
    log.reload
    assert_nil log.shift_assignment_id
  end
end
