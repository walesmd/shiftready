# frozen_string_literal: true

FactoryBot.define do
  factory :worker_profile do
    association :user, :worker, :without_profile_callback
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    sequence(:phone) { |n| "+1210555#{n.to_s.rjust(4, '0')}" }
    address_line_1 { Faker::Address.street_address }
    city { "San Antonio" }
    state { "TX" }
    zip_code { "78201" }
    is_active { true }
    onboarding_completed { false }
    over_18_confirmed { true }
    total_shifts_assigned { 0 }
    total_shifts_completed { 0 }
    no_show_count { 0 }
    preferred_payment_method { :direct_deposit }

    trait :onboarded do
      onboarding_completed { true }
      ssn_encrypted { "encrypted_ssn_123" }
      terms_accepted_at { Time.current }
      sms_consent_given_at { Time.current }
    end

    trait :with_stats do
      total_shifts_assigned { 10 }
      total_shifts_completed { 8 }
      no_show_count { 1 }
      average_rating { 4.5 }
      average_response_time_minutes { 15 }
    end

    trait :perfect_record do
      total_shifts_assigned { 20 }
      total_shifts_completed { 20 }
      no_show_count { 0 }
      average_rating { 5.0 }
      average_response_time_minutes { 5 }
    end

    trait :poor_record do
      total_shifts_assigned { 10 }
      total_shifts_completed { 5 }
      no_show_count { 3 }
      average_rating { 2.0 }
      average_response_time_minutes { 60 }
    end
  end
end
