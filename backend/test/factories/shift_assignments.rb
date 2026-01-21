# frozen_string_literal: true

FactoryBot.define do
  factory :shift_assignment do
    association :shift, :recruiting
    association :worker_profile, :onboarded
    assigned_at { Time.current }
    assigned_by { :algorithm }
    status { :offered }

    trait :offered do
      status { :offered }
      sms_sent_at { Time.current }
    end

    trait :accepted do
      status { :accepted }
      accepted_at { Time.current }
      response_received_at { Time.current }
      response_method { :sms }
      response_value { :accepted }
    end

    trait :declined do
      status { :declined }
      response_received_at { Time.current }
      response_method { :sms }
      response_value { :declined }
      decline_reason { "Schedule conflict" }
    end

    trait :confirmed do
      status { :confirmed }
      accepted_at { 1.hour.ago }
      confirmed_at { Time.current }
      response_received_at { 1.hour.ago }
      response_method { :sms }
      response_value { :accepted }
    end

    trait :checked_in do
      status { :checked_in }
      accepted_at { 2.hours.ago }
      confirmed_at { 1.hour.ago }
      checked_in_at { Time.current }
      actual_start_time { Time.current }
    end

    trait :checked_out do
      status { :checked_in }
      accepted_at { 9.hours.ago }
      confirmed_at { 8.hours.ago }
      checked_in_at { 8.hours.ago }
      actual_start_time { 8.hours.ago }
      checked_out_at { Time.current }
      actual_end_time { Time.current }
      actual_hours_worked { 8.0 }
    end

    trait :timesheet_approved do
      checked_out
      timesheet_approved_at { Time.current }
      association :timesheet_approved_by_employer, factory: [:employer_profile, :can_approve]
    end

    trait :completed do
      status { :completed }
      accepted_at { 1.day.ago }
      confirmed_at { 1.day.ago }
      checked_in_at { 1.day.ago.change(hour: 8) }
      actual_start_time { 1.day.ago.change(hour: 8) }
      checked_out_at { 1.day.ago.change(hour: 16) }
      actual_end_time { 1.day.ago.change(hour: 16) }
      actual_hours_worked { 8.0 }
      timesheet_approved_at { 1.day.ago.change(hour: 17) }
      completed_successfully { true }
    end

    trait :no_show do
      status { :no_show }
      no_show { true }
      completed_successfully { false }
    end

    trait :cancelled do
      status { :cancelled }
      cancelled_at { Time.current }
      cancelled_by { :worker }
      cancellation_reason { "Personal emergency" }
    end

    trait :with_ratings do
      worker_rating { 5 }
      employer_rating { 4 }
      worker_feedback { "Great shift!" }
      employer_feedback { "Good worker" }
    end

    trait :manual_assignment do
      assigned_by { :manual_admin }
    end

    trait :self_selected do
      assigned_by { :worker_self_select }
    end
  end
end
