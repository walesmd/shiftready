# frozen_string_literal: true

require "test_helper"

class WorkerProfileTest < ActiveSupport::TestCase
  # Associations
  test "belongs to user" do
    profile = create(:worker_profile)
    assert profile.user.present?
    assert profile.user.worker?
  end

  test "has many worker_availabilities" do
    profile = create(:worker_profile)
    availability = create(:worker_availability, worker_profile: profile)
    assert_includes profile.worker_availabilities, availability
  end

  test "has many worker_preferred_job_types" do
    profile = create(:worker_profile)
    job_type = create(:worker_preferred_job_type, worker_profile: profile)
    assert_includes profile.worker_preferred_job_types, job_type
  end

  test "has many shift_assignments" do
    profile = create(:worker_profile, :onboarded)
    assignment = create(:shift_assignment, worker_profile: profile)
    assert_includes profile.shift_assignments, assignment
  end

  test "destroys associated availabilities when destroyed" do
    profile = create(:worker_profile)
    availability = create(:worker_availability, worker_profile: profile)
    availability_id = availability.id

    profile.destroy
    assert_nil WorkerAvailability.find_by(id: availability_id)
  end

  # Validations
  test "requires first_name" do
    profile = build(:worker_profile, first_name: nil)
    assert_not profile.valid?
    assert_includes profile.errors[:first_name], "can't be blank"
  end

  test "requires last_name" do
    profile = build(:worker_profile, last_name: nil)
    assert_not profile.valid?
    assert_includes profile.errors[:last_name], "can't be blank"
  end

  test "requires phone" do
    profile = build(:worker_profile, phone: nil)
    assert_not profile.valid?
    assert_includes profile.errors[:phone], "can't be blank"
  end

  test "requires unique phone" do
    create(:worker_profile, phone: "+12105551234")
    profile = build(:worker_profile, phone: "+12105551234")
    assert_not profile.valid?
    assert_includes profile.errors[:phone], "has already been taken"
  end

  test "validates phone format" do
    profile = build(:worker_profile, phone: "invalid")
    assert_not profile.valid?
    assert_includes profile.errors[:phone], "must be a valid phone number"
  end

  test "accepts valid phone formats" do
    profile = build(:worker_profile, phone: "+12105559999")
    assert profile.valid?
  end

  test "requires address_line_1" do
    profile = build(:worker_profile, address_line_1: nil)
    assert_not profile.valid?
    assert_includes profile.errors[:address_line_1], "can't be blank"
  end

  test "requires city" do
    profile = build(:worker_profile, city: nil)
    assert_not profile.valid?
    assert_includes profile.errors[:city], "can't be blank"
  end

  test "requires state" do
    profile = build(:worker_profile, state: nil)
    assert_not profile.valid?
    assert_includes profile.errors[:state], "can't be blank"
  end

  test "requires state to be 2 characters" do
    profile = build(:worker_profile, state: "Texas")
    assert_not profile.valid?
    assert_includes profile.errors[:state], "is the wrong length (should be 2 characters)"
  end

  test "requires zip_code" do
    profile = build(:worker_profile, zip_code: nil)
    assert_not profile.valid?
    assert_includes profile.errors[:zip_code], "can't be blank"
  end

  test "validates zip_code format for 5 digits" do
    profile = build(:worker_profile, zip_code: "78201")
    assert profile.valid?
  end

  test "validates zip_code format for 5+4 digits" do
    profile = build(:worker_profile, zip_code: "78201-1234")
    assert profile.valid?
  end

  test "rejects invalid zip_code format" do
    profile = build(:worker_profile, zip_code: "invalid")
    assert_not profile.valid?
    assert_includes profile.errors[:zip_code], "must be a valid ZIP code"
  end

  test "validates average_rating range" do
    profile = build(:worker_profile, average_rating: 6.0)
    assert_not profile.valid?
    assert_includes profile.errors[:average_rating], "must be less than or equal to 5"
  end

  test "validates reliability_score range" do
    profile = build(:worker_profile, reliability_score: 101)
    assert_not profile.valid?
    assert_includes profile.errors[:reliability_score], "must be less than or equal to 100"
  end

  test "requires ssn_encrypted when onboarding completed" do
    profile = build(:worker_profile, onboarding_completed: true, ssn_encrypted: nil)
    assert_not profile.valid?
    assert_includes profile.errors[:ssn_encrypted], "can't be blank"
  end

  # Enums
  test "preferred_payment_method enum has correct values" do
    assert_equal({ "direct_deposit" => 0, "check" => 1 }, WorkerProfile.preferred_payment_methods)
  end

  # Scopes
  test "active scope returns only active profiles" do
    active_profile = create(:worker_profile, is_active: true)
    inactive_profile = create(:worker_profile, is_active: false)

    assert_includes WorkerProfile.active, active_profile
    assert_not_includes WorkerProfile.active, inactive_profile
  end

  test "onboarded scope returns only onboarded profiles" do
    onboarded = create(:worker_profile, :onboarded)
    not_onboarded = create(:worker_profile, onboarding_completed: false)

    assert_includes WorkerProfile.onboarded, onboarded
    assert_not_includes WorkerProfile.onboarded, not_onboarded
  end

  # Instance methods
  test "full_name returns first and last name" do
    profile = build(:worker_profile, first_name: "John", last_name: "Doe")
    assert_equal "John Doe", profile.full_name
  end

  test "full_address returns formatted address" do
    profile = build(:worker_profile,
                    address_line_1: "123 Main St",
                    address_line_2: "Apt 4",
                    city: "San Antonio",
                    state: "TX",
                    zip_code: "78201")
    assert_equal "123 Main St, Apt 4, San Antonio, TX, 78201", profile.full_address
  end

  test "full_address excludes nil address_line_2" do
    profile = build(:worker_profile,
                    address_line_1: "123 Main St",
                    address_line_2: nil,
                    city: "San Antonio",
                    state: "TX",
                    zip_code: "78201")
    assert_equal "123 Main St, San Antonio, TX, 78201", profile.full_address
  end

  # Attendance rate calculation
  test "attendance_rate returns 0 when no shifts assigned" do
    profile = create(:worker_profile, total_shifts_assigned: 0, total_shifts_completed: 0)
    assert_equal 0, profile.attendance_rate
  end

  test "attendance_rate calculates correct percentage" do
    profile = create(:worker_profile, total_shifts_assigned: 10, total_shifts_completed: 8)
    assert_equal 80.0, profile.attendance_rate
  end

  test "attendance_rate returns 100 for perfect attendance" do
    profile = create(:worker_profile, total_shifts_assigned: 20, total_shifts_completed: 20)
    assert_equal 100.0, profile.attendance_rate
  end

  # No-show rate calculation
  test "no_show_rate returns 0 when no shifts assigned" do
    profile = create(:worker_profile, total_shifts_assigned: 0, no_show_count: 0)
    assert_equal 0, profile.no_show_rate
  end

  test "no_show_rate calculates correct percentage" do
    profile = create(:worker_profile, total_shifts_assigned: 10, no_show_count: 2)
    assert_equal 20.0, profile.no_show_rate
  end

  test "no_show_rate returns 0 for perfect record" do
    profile = create(:worker_profile, total_shifts_assigned: 10, no_show_count: 0)
    assert_equal 0, profile.no_show_rate
  end

  # Reliability score calculation
  test "calculate_reliability_score returns 0 when no shifts assigned" do
    profile = create(:worker_profile, total_shifts_assigned: 0)
    assert_equal 0, profile.calculate_reliability_score
  end

  test "calculate_reliability_score uses weighted algorithm" do
    # Algorithm: Attendance (40%) + Rating (40%) + Response (20%)
    # 80% attendance = 32 points (80 * 0.4)
    # 4.5 rating = 36 points (4.5 * 20 * 0.4)
    # 15 min response = 18.5 points (20 - 15/10 = 18.5... but max is 20 so * 0.2 = ~3.7)
    profile = create(:worker_profile,
                     total_shifts_assigned: 10,
                     total_shifts_completed: 8,
                     average_rating: 4.5,
                     average_response_time_minutes: 15)

    # Expected: 32 + 36 + (20 - 1.5) * 0.2 = 32 + 36 + 3.7 = 71.7
    # Let's calculate: attendance_score = 80 * 0.4 = 32
    #                  rating_score = 4.5 * 20 * 0.4 = 36
    #                  response_score = max(20 - 15/10, 0) = 18.5, but need to check actual formula
    # Looking at the code: response_score = [20 - (average_response_time_minutes / 10.0), 0].max
    # So: 20 - 1.5 = 18.5 (the response_score itself, not weighted yet)
    # Wait, the code doesn't multiply by 0.2 for response, let me re-check...
    # Actually looking at the code, response_score is calculated as [20 - (avg/10), 0].max
    # That's not weighted by 0.2, so total = 32 + 36 + 18.5 = 86.5

    expected_score = 86.5
    assert_in_delta expected_score, profile.calculate_reliability_score, 0.1
  end

  test "calculate_reliability_score handles nil rating" do
    profile = create(:worker_profile,
                     total_shifts_assigned: 10,
                     total_shifts_completed: 8,
                     average_rating: nil,
                     average_response_time_minutes: 15)

    # attendance_score = 80 * 0.4 = 32
    # rating_score = 0 * 20 * 0.4 = 0
    # response_score = 20 - 1.5 = 18.5
    expected_score = 50.5
    assert_in_delta expected_score, profile.calculate_reliability_score, 0.1
  end

  test "calculate_reliability_score handles nil response time" do
    profile = create(:worker_profile,
                     total_shifts_assigned: 10,
                     total_shifts_completed: 10,
                     average_rating: 5.0,
                     average_response_time_minutes: nil)

    # attendance_score = 100 * 0.4 = 40
    # rating_score = 5.0 * 20 * 0.4 = 40
    # response_score = 0 (nil case)
    expected_score = 80.0
    assert_in_delta expected_score, profile.calculate_reliability_score, 0.1
  end

  test "calculate_reliability_score caps response score at 0" do
    profile = create(:worker_profile,
                     total_shifts_assigned: 10,
                     total_shifts_completed: 10,
                     average_rating: 5.0,
                     average_response_time_minutes: 300) # Very slow response

    # response_score = max(20 - 30, 0) = 0
    expected_score = 80.0 # 40 + 40 + 0
    assert_in_delta expected_score, profile.calculate_reliability_score, 0.1
  end

  test "calculate_reliability_score for perfect worker" do
    profile = create(:worker_profile, :perfect_record)

    # attendance: 100 * 0.4 = 40
    # rating: 5.0 * 20 * 0.4 = 40
    # response: 20 - 0.5 = 19.5
    expected_score = 99.5
    assert_in_delta expected_score, profile.calculate_reliability_score, 0.1
  end

  test "calculate_reliability_score for poor worker" do
    profile = create(:worker_profile, :poor_record)

    # attendance: 50 * 0.4 = 20
    # rating: 2.0 * 20 * 0.4 = 16
    # response: 20 - 6 = 14
    expected_score = 50.0
    assert_in_delta expected_score, profile.calculate_reliability_score, 0.1
  end

  # update_reliability_score!
  test "update_reliability_score! updates the reliability_score attribute" do
    profile = create(:worker_profile, :with_stats, reliability_score: nil)

    profile.update_reliability_score!
    profile.reload

    assert profile.reliability_score.present?
    assert_in_delta profile.calculate_reliability_score, profile.reliability_score, 0.1
  end

  # available_at scope
  test "available_at scope returns workers available at given time" do
    profile = create(:worker_profile)
    # Monday at 10am
    create(:worker_availability, :monday, worker_profile: profile, start_time: "08:00", end_time: "17:00", is_active: true)

    monday_10am = Time.zone.local(2025, 1, 6, 10, 0, 0) # A Monday

    assert_includes WorkerProfile.available_at(monday_10am), profile
  end

  test "available_at scope excludes workers not available at given time" do
    profile = create(:worker_profile)
    # Monday 8am-12pm only
    create(:worker_availability, :monday, worker_profile: profile, start_time: "08:00", end_time: "12:00", is_active: true)

    monday_3pm = Time.zone.local(2025, 1, 6, 15, 0, 0) # A Monday at 3pm

    assert_not_includes WorkerProfile.available_at(monday_3pm), profile
  end

  test "available_at scope excludes workers with inactive availability" do
    profile = create(:worker_profile)
    create(:worker_availability, :monday, :inactive, worker_profile: profile, start_time: "08:00", end_time: "17:00")

    monday_10am = Time.zone.local(2025, 1, 6, 10, 0, 0)

    assert_not_includes WorkerProfile.available_at(monday_10am), profile
  end
end
