# frozen_string_literal: true

FactoryBot.define do
  factory :recruiting_activity_log do
    association :shift, :recruiting
    action { 'recruiting_started' }
    source { 'algorithm' }
    details { {} }

    trait :with_worker do
      association :worker_profile, :onboarded
    end

    trait :with_assignment do
      association :worker_profile, :onboarded
      association :shift_assignment
    end

    trait :recruiting_started do
      action { 'recruiting_started' }
      details { { slots_total: 5, slots_filled: 0, start_datetime: 1.day.from_now.iso8601 } }
    end

    trait :worker_scored do
      with_worker
      action { 'worker_scored' }
      details { { score: 85.5, score_breakdown: { distance: 30, reliability: 20, job_type: 15, rating: 10, response_time: 5, experience: 5.5 } } }
    end

    trait :offer_sent do
      with_assignment
      action { 'offer_sent' }
      details { { rank: 1, algorithm_score: 85.5, distance_miles: 3.5 } }
    end

    trait :offer_accepted do
      with_assignment
      action { 'offer_accepted' }
      details { { response_time_minutes: 5, slots_filled: 1, slots_total: 5 } }
    end

    trait :offer_declined do
      with_assignment
      action { 'offer_declined' }
      details { { reason: 'schedule_conflict', response_time_minutes: 10 } }
    end

    trait :offer_timeout do
      with_assignment
      action { 'offer_timeout' }
      details { { timeout_minutes: 15 } }
    end
  end
end
