# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    jti { SecureRandom.uuid }
    role { :worker }

    trait :worker do
      role { :worker }
    end

    trait :employer do
      role { :employer }
    end

    trait :admin do
      role { :admin }
    end

    # Skip automatic profile creation for testing
    trait :without_profile_callback do
      after(:build) do |user|
        user.define_singleton_method(:create_profile_for_role) { nil }
      end
    end
  end
end
