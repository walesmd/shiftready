# frozen_string_literal: true

module WorkerProfileAlgorithmScopes
  extend ActiveSupport::Concern

  included do
    scope :with_job_type_preference, ->(job_type) {
      joins(:worker_preferred_job_types)
        .where(worker_preferred_job_types: { job_type: job_type })
        .distinct
    }

    scope :with_coordinates, -> {
      where.not(latitude: nil, longitude: nil)
    }

    scope :not_blocked_by_company, ->(company) {
      where.not(id: BlockList.where(blocker: company, blocked_type: 'WorkerProfile').select(:blocked_id))
           .where.not(id: BlockList.where(blocked: company, blocker_type: 'WorkerProfile').select(:blocker_id))
    }

    scope :not_already_offered, ->(shift) {
      where.not(id: shift.shift_assignments.select(:worker_profile_id))
    }
  end
end
