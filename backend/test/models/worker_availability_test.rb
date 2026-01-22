# frozen_string_literal: true

require "test_helper"

class WorkerAvailabilityTest < ActiveSupport::TestCase
  # Associations
  test "belongs to worker_profile" do
    availability = create(:worker_availability)
    assert availability.worker_profile.present?
  end

  # Validations
  test "requires day_of_week" do
    availability = build(:worker_availability, day_of_week: nil)
    assert_not availability.valid?
    assert_includes availability.errors[:day_of_week], "can't be blank"
  end

  test "requires day_of_week to be 0-6" do
    availability = build(:worker_availability, day_of_week: 7)
    assert_not availability.valid?
    assert_includes availability.errors[:day_of_week], "is not included in the list"
  end

  test "allows valid day_of_week values 0-6" do
    (0..6).each do |day|
      availability = build(:worker_availability, day_of_week: day)
      assert availability.valid?, "day_of_week #{day} should be valid"
    end
  end

  test "requires start_time" do
    availability = build(:worker_availability, start_time: nil)
    assert_not availability.valid?
    assert_includes availability.errors[:start_time], "can't be blank"
  end

  test "requires end_time" do
    availability = build(:worker_availability, end_time: nil)
    assert_not availability.valid?
    assert_includes availability.errors[:end_time], "can't be blank"
  end

  test "end_time must be after start_time" do
    availability = build(:worker_availability, start_time: "17:00", end_time: "08:00")
    assert_not availability.valid?
    assert_includes availability.errors[:end_time], "must be after start time"
  end

  test "allows same start and end time" do
    availability = build(:worker_availability, start_time: "08:00", end_time: "08:01")
    assert availability.valid?
  end

  test "requires unique combination of worker, day, start_time, end_time" do
    worker = create(:worker_profile)
    create(:worker_availability,
           worker_profile: worker,
           day_of_week: 1,
           start_time: "08:00",
           end_time: "17:00")

    duplicate = build(:worker_availability,
                      worker_profile: worker,
                      day_of_week: 1,
                      start_time: "08:00",
                      end_time: "17:00")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:day_of_week], "availability already exists for this time range"
  end

  test "allows same time range on different days" do
    worker = create(:worker_profile)
    create(:worker_availability,
           worker_profile: worker,
           day_of_week: 1,
           start_time: "08:00",
           end_time: "17:00")

    different_day = build(:worker_availability,
                          worker_profile: worker,
                          day_of_week: 2,
                          start_time: "08:00",
                          end_time: "17:00")

    assert different_day.valid?
  end

  # ============================================================
  # OVERLAP VALIDATION - Critical Business Logic
  # ============================================================

  test "prevents overlapping windows on same day for same worker" do
    worker = create(:worker_profile)
    # Existing: 8am - 5pm
    create(:worker_availability,
           worker_profile: worker,
           day_of_week: 1,
           start_time: "08:00",
           end_time: "17:00",
           is_active: true)

    # New overlapping: 12pm - 8pm (overlaps 12-5pm)
    overlapping = build(:worker_availability,
                        worker_profile: worker,
                        day_of_week: 1,
                        start_time: "12:00",
                        end_time: "20:00",
                        is_active: true)

    assert_not overlapping.valid?
    assert_includes overlapping.errors[:base], "This time window overlaps with an existing availability window"
  end

  test "prevents new window that starts during existing window" do
    worker = create(:worker_profile)
    # Existing: 8am - 2pm
    create(:worker_availability,
           worker_profile: worker,
           day_of_week: 1,
           start_time: "08:00",
           end_time: "14:00",
           is_active: true)

    # New: 10am - 4pm (starts during existing)
    overlapping = build(:worker_availability,
                        worker_profile: worker,
                        day_of_week: 1,
                        start_time: "10:00",
                        end_time: "16:00",
                        is_active: true)

    assert_not overlapping.valid?
  end

  test "prevents new window that ends during existing window" do
    worker = create(:worker_profile)
    # Existing: 12pm - 8pm
    create(:worker_availability,
           worker_profile: worker,
           day_of_week: 1,
           start_time: "12:00",
           end_time: "20:00",
           is_active: true)

    # New: 8am - 2pm (ends during existing)
    overlapping = build(:worker_availability,
                        worker_profile: worker,
                        day_of_week: 1,
                        start_time: "08:00",
                        end_time: "14:00",
                        is_active: true)

    assert_not overlapping.valid?
  end

  test "prevents new window that completely contains existing" do
    worker = create(:worker_profile)
    # Existing: 10am - 2pm
    create(:worker_availability,
           worker_profile: worker,
           day_of_week: 1,
           start_time: "10:00",
           end_time: "14:00",
           is_active: true)

    # New: 8am - 6pm (completely contains existing)
    overlapping = build(:worker_availability,
                        worker_profile: worker,
                        day_of_week: 1,
                        start_time: "08:00",
                        end_time: "18:00",
                        is_active: true)

    assert_not overlapping.valid?
  end

  test "prevents new window that is completely contained by existing" do
    worker = create(:worker_profile)
    # Existing: 8am - 6pm
    create(:worker_availability,
           worker_profile: worker,
           day_of_week: 1,
           start_time: "08:00",
           end_time: "18:00",
           is_active: true)

    # New: 10am - 2pm (completely inside existing)
    overlapping = build(:worker_availability,
                        worker_profile: worker,
                        day_of_week: 1,
                        start_time: "10:00",
                        end_time: "14:00",
                        is_active: true)

    assert_not overlapping.valid?
  end

  test "allows adjacent non-overlapping windows" do
    worker = create(:worker_profile)
    # Existing: 8am - 12pm
    create(:worker_availability,
           worker_profile: worker,
           day_of_week: 1,
           start_time: "08:00",
           end_time: "12:00",
           is_active: true)

    # New: 12pm - 5pm (starts exactly when existing ends)
    adjacent = build(:worker_availability,
                     worker_profile: worker,
                     day_of_week: 1,
                     start_time: "12:00",
                     end_time: "17:00",
                     is_active: true)

    assert adjacent.valid?
  end

  test "allows gap between windows" do
    worker = create(:worker_profile)
    # Existing: 8am - 11am
    create(:worker_availability,
           worker_profile: worker,
           day_of_week: 1,
           start_time: "08:00",
           end_time: "11:00",
           is_active: true)

    # New: 1pm - 5pm (gap of 2 hours)
    non_overlapping = build(:worker_availability,
                            worker_profile: worker,
                            day_of_week: 1,
                            start_time: "13:00",
                            end_time: "17:00",
                            is_active: true)

    assert non_overlapping.valid?
  end

  test "allows overlapping windows for different workers" do
    worker1 = create(:worker_profile)
    worker2 = create(:worker_profile)

    create(:worker_availability,
           worker_profile: worker1,
           day_of_week: 1,
           start_time: "08:00",
           end_time: "17:00",
           is_active: true)

    # Same time for different worker
    availability = build(:worker_availability,
                         worker_profile: worker2,
                         day_of_week: 1,
                         start_time: "08:00",
                         end_time: "17:00",
                         is_active: true)

    assert availability.valid?
  end

  test "allows overlapping with inactive windows" do
    worker = create(:worker_profile)
    # Existing inactive: 8am - 5pm
    create(:worker_availability,
           worker_profile: worker,
           day_of_week: 1,
           start_time: "08:00",
           end_time: "17:00",
           is_active: false) # INACTIVE

    # New overlapping but active
    overlapping = build(:worker_availability,
                        worker_profile: worker,
                        day_of_week: 1,
                        start_time: "12:00",
                        end_time: "20:00",
                        is_active: true)

    assert overlapping.valid?
  end

  test "allows updating existing availability without self-overlap error" do
    worker = create(:worker_profile)
    availability = create(:worker_availability,
                          worker_profile: worker,
                          day_of_week: 1,
                          start_time: "08:00",
                          end_time: "17:00",
                          is_active: true)

    # Update end time on same record
    availability.end_time = "18:00"
    assert availability.valid?
  end

  # Scopes
  test "active scope returns only active availabilities" do
    worker = create(:worker_profile)
    active = create(:worker_availability, worker_profile: worker, is_active: true)
    inactive = create(:worker_availability, :inactive, :tuesday, worker_profile: worker)

    assert_includes WorkerAvailability.active, active
    assert_not_includes WorkerAvailability.active, inactive
  end

  test "for_day scope filters by day_of_week" do
    worker = create(:worker_profile)
    monday = create(:worker_availability, :monday, worker_profile: worker)
    tuesday = create(:worker_availability, :tuesday, worker_profile: worker)

    assert_includes WorkerAvailability.for_day(1), monday
    assert_not_includes WorkerAvailability.for_day(1), tuesday
  end

  # Instance methods
  test "day_name returns correct day name" do
    assert_equal "Sunday", build(:worker_availability, day_of_week: 0).day_name
    assert_equal "Monday", build(:worker_availability, day_of_week: 1).day_name
    assert_equal "Tuesday", build(:worker_availability, day_of_week: 2).day_name
    assert_equal "Wednesday", build(:worker_availability, day_of_week: 3).day_name
    assert_equal "Thursday", build(:worker_availability, day_of_week: 4).day_name
    assert_equal "Friday", build(:worker_availability, day_of_week: 5).day_name
    assert_equal "Saturday", build(:worker_availability, day_of_week: 6).day_name
  end

  test "time_range returns formatted time range" do
    availability = build(:worker_availability, start_time: "08:00", end_time: "17:00")
    assert_equal "08:00 AM - 05:00 PM", availability.time_range
  end

  test "time_range handles afternoon times" do
    availability = build(:worker_availability, start_time: "14:00", end_time: "22:00")
    assert_equal "02:00 PM - 10:00 PM", availability.time_range
  end

  # ============================================================
  # EDGE CASES
  # ============================================================

  test "handles late evening times" do
    worker = create(:worker_profile)
    # Late evening shift ending before midnight
    evening = build(:worker_availability,
                    worker_profile: worker,
                    day_of_week: 5, # Friday
                    start_time: "22:00",
                    end_time: "23:59",
                    is_active: true)

    assert evening.valid?
  end

  test "handles early morning times" do
    worker = create(:worker_profile)
    early = build(:worker_availability,
                  worker_profile: worker,
                  day_of_week: 1,
                  start_time: "00:00",
                  end_time: "06:00",
                  is_active: true)

    assert early.valid?
  end

  test "multiple non-overlapping windows on same day" do
    worker = create(:worker_profile)

    # Morning shift
    create(:worker_availability,
           worker_profile: worker,
           day_of_week: 1,
           start_time: "06:00",
           end_time: "10:00",
           is_active: true)

    # Afternoon shift
    afternoon = create(:worker_availability,
                       worker_profile: worker,
                       day_of_week: 1,
                       start_time: "14:00",
                       end_time: "18:00",
                       is_active: true)

    # Evening shift
    evening = build(:worker_availability,
                    worker_profile: worker,
                    day_of_week: 1,
                    start_time: "20:00",
                    end_time: "23:00",
                    is_active: true)

    assert afternoon.persisted?
    assert evening.valid?
  end
end
