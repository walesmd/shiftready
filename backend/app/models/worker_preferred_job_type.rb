# frozen_string_literal: true

class WorkerPreferredJobType < ApplicationRecord
  # Associations
  belongs_to :worker_profile

  # Validations
  validates :job_type, presence: true
  validates :job_type, uniqueness: { scope: :worker_profile_id, message: 'already exists for this worker' }

  # Common job types (can be moved to a constant or config)
  AVAILABLE_JOB_TYPES = %w[
    warehouse
    moving
    event_setup
    event_teardown
    packing
    loading
    unloading
    assembly
    construction
    landscaping
    delivery
    retail
    hospitality
    cleaning
    general_labor
  ].freeze

  validates :job_type, inclusion: { in: AVAILABLE_JOB_TYPES, message: '%{value} is not a valid job type' }

  # Scopes
  scope :for_job_type, ->(type) { where(job_type: type) }
end
