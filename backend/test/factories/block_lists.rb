# frozen_string_literal: true

FactoryBot.define do
  factory :block_list do
    association :blocker, factory: :company
    association :blocked, factory: :worker_profile
    reason { "Policy violation" }

    trait :worker_blocked_company do
      association :blocker, factory: :worker_profile
      association :blocked, factory: :company
      reason { "Bad experience" }
    end

    trait :company_blocked_worker do
      association :blocker, factory: :company
      association :blocked, factory: :worker_profile
      reason { "No-show" }
    end
  end
end
