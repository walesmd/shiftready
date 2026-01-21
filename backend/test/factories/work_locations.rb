# frozen_string_literal: true

FactoryBot.define do
  factory :work_location do
    association :company
    sequence(:name) { |n| "Location #{n}" }
    address_line_1 { Faker::Address.street_address }
    city { "San Antonio" }
    state { "TX" }
    zip_code { "78201" }
    is_active { true }
    latitude { 29.4241 }
    longitude { -98.4936 }
    parking_notes { "Park in lot A" }
    arrival_instructions { "Check in at front desk" }

    trait :inactive do
      is_active { false }
    end
  end
end
