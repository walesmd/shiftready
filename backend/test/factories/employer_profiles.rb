# frozen_string_literal: true

FactoryBot.define do
  factory :employer_profile do
    association :user, :employer, :without_profile_callback
    association :company
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    sequence(:phone) { |n| "+1210666#{n.to_s.rjust(4, '0')}" }
    title { "Manager" }
    onboarding_completed { false }
    can_post_shifts { true }
    can_approve_timesheets { false }
    is_billing_contact { false }

    trait :onboarded do
      onboarding_completed { true }
      terms_accepted_at { Time.current }
      msa_accepted_at { Time.current }
    end

    trait :with_full_permissions do
      onboarding_completed { true }
      can_post_shifts { true }
      can_approve_timesheets { true }
      is_billing_contact { true }
    end

    trait :billing_contact do
      is_billing_contact { true }
    end

    trait :can_approve do
      onboarding_completed { true }
      can_approve_timesheets { true }
    end
  end
end
