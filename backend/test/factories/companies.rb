# frozen_string_literal: true

FactoryBot.define do
  factory :company do
    sequence(:name) { |n| "Test Company #{n}" }
    industry { "construction" }
    billing_address_line_1 { Faker::Address.street_address }
    billing_city { "San Antonio" }
    billing_state { "TX" }
    billing_zip_code { "78201" }
    billing_email { Faker::Internet.email }
    billing_phone { "+12105551234" }
    is_active { true }
    workers_needed_per_week { "5-10" }
    typical_roles { "warehouse,moving" }

    trait :inactive do
      is_active { false }
    end
  end
end
