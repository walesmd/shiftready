# frozen_string_literal: true

FactoryBot.define do
  factory :worker_availability do
    association :worker_profile
    day_of_week { 1 } # Monday
    start_time { "08:00:00" }
    end_time { "17:00:00" }
    is_active { true }

    trait :morning do
      start_time { "06:00:00" }
      end_time { "12:00:00" }
    end

    trait :afternoon do
      start_time { "12:00:00" }
      end_time { "18:00:00" }
    end

    trait :evening do
      start_time { "18:00:00" }
      end_time { "23:00:00" }
    end

    trait :all_day do
      start_time { "00:00:00" }
      end_time { "23:59:59" }
    end

    trait :inactive do
      is_active { false }
    end

    # Days of week
    trait :sunday do
      day_of_week { 0 }
    end

    trait :monday do
      day_of_week { 1 }
    end

    trait :tuesday do
      day_of_week { 2 }
    end

    trait :wednesday do
      day_of_week { 3 }
    end

    trait :thursday do
      day_of_week { 4 }
    end

    trait :friday do
      day_of_week { 5 }
    end

    trait :saturday do
      day_of_week { 6 }
    end
  end
end
