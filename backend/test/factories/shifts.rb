# frozen_string_literal: true

FactoryBot.define do
  factory :shift do
    association :company
    association :work_location
    association :created_by_employer, factory: [:employer_profile, :onboarded]
    title { "General Labor Shift" }
    description { "Help with warehouse duties including packing and loading" }
    job_type { "warehouse" }
    start_datetime { 1.day.from_now.change(hour: 8) }
    end_datetime { 1.day.from_now.change(hour: 16) }
    pay_rate_cents { 1500 } # $15/hr
    slots_total { 5 }
    slots_filled { 0 }
    min_workers_needed { 1 }
    status { :draft }

    trait :posted do
      status { :posted }
      posted_at { Time.current }
    end

    trait :recruiting do
      status { :recruiting }
      posted_at { 1.hour.ago }
      recruiting_started_at { Time.current }
    end

    trait :filled do
      status { :filled }
      slots_filled { 5 }
      filled_at { Time.current }
    end

    trait :in_progress do
      status { :in_progress }
      start_datetime { 1.hour.ago }
      end_datetime { 7.hours.from_now }
    end

    trait :completed do
      status { :completed }
      start_datetime { 2.days.ago.change(hour: 8) }
      end_datetime { 2.days.ago.change(hour: 16) }
      completed_at { 2.days.ago.change(hour: 16) }
    end

    trait :cancelled do
      status { :cancelled }
      cancelled_at { Time.current }
      cancellation_reason { "Business needs changed" }
    end

    trait :starting_soon do
      start_datetime { 30.minutes.from_now }
      end_datetime { 8.hours.from_now }
    end

    trait :past do
      start_datetime { 2.days.ago.change(hour: 8) }
      end_datetime { 2.days.ago.change(hour: 16) }
    end

    trait :single_slot do
      slots_total { 1 }
    end

    trait :high_pay do
      pay_rate_cents { 2500 } # $25/hr
    end

    # Ensure work_location belongs to same company
    after(:build) do |shift|
      if shift.work_location.company_id != shift.company_id
        shift.work_location = build(:work_location, company: shift.company)
      end
      if shift.created_by_employer.company_id != shift.company_id
        shift.created_by_employer = build(:employer_profile, :onboarded, company: shift.company)
      end
    end
  end
end
