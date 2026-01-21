# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    association :messageable, factory: :worker_profile
    body { "Test message content" }
    channel { :sms }
    direction { :outbound }
    from_phone { "+18005551234" }
    to_phone { "+12105551234" }
    thread_id { SecureRandom.uuid }

    trait :sms do
      channel { :sms }
    end

    trait :email do
      channel { :email }
      subject { "Test Subject" }
    end

    trait :in_app do
      channel { :in_app }
    end

    trait :inbound do
      direction { :inbound }
    end

    trait :outbound do
      direction { :outbound }
    end

    trait :sent do
      sent_at { Time.current }
      sms_status { :sent }
    end

    trait :delivered do
      sent_at { 1.minute.ago }
      delivered_at { Time.current }
      sms_status { :delivered }
    end

    trait :failed do
      sent_at { Time.current }
      failed_at { Time.current }
      sms_status { :failed }
      sms_error_code { "30003" }
      sms_error_message { "Unreachable destination" }
    end
  end
end
