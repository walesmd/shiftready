# frozen_string_literal: true

FactoryBot.define do
  factory :payment do
    association :shift_assignment, :completed
    worker_profile { shift_assignment.worker_profile }
    company { shift_assignment.shift.company }
    amount_cents { 12000 } # $120
    currency { "USD" }
    status { :pending }
    payment_method { :direct_deposit }
    tax_year { Time.current.year }
    hours_worked { 8.0 }
    pay_rate_cents { 1500 }

    trait :processing do
      status { :processing }
      processed_at { Time.current }
    end

    trait :completed do
      status { :completed }
      processed_at { 1.day.ago }
    end

    trait :failed do
      status { :failed }
      processed_at { 1.day.ago }
      failed_at { Time.current }
      failure_reason { "Insufficient funds" }
    end

    trait :refunded do
      status { :refunded }
      processed_at { 3.days.ago }
      refunded_at { Time.current }
      refund_reason { "Shift cancelled" }
    end

    trait :disputed do
      status { :disputed }
      processed_at { 3.days.ago }
      disputed_at { Time.current }
      dispute_reason { "Hours disputed" }
    end

    trait :large_amount do
      amount_cents { 70000 } # $700
    end

    trait :included_in_1099 do
      status { :completed }
      included_in_1099 { true }
    end
  end
end
