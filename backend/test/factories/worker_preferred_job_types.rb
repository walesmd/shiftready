# frozen_string_literal: true

FactoryBot.define do
  factory :worker_preferred_job_type do
    association :worker_profile
    job_type { "warehouse" }

    WorkerPreferredJobType::AVAILABLE_JOB_TYPES.each do |type|
      trait type.to_sym do
        job_type { type }
      end
    end
  end
end
