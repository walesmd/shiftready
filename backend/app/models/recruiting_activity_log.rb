# frozen_string_literal: true

class RecruitingActivityLog < ApplicationRecord
  # Associations
  belongs_to :shift
  belongs_to :worker_profile, optional: true
  belongs_to :shift_assignment, optional: true

  # Action constants
  ACTIONS = %w[
    recruiting_started
    recruiting_paused
    recruiting_resumed
    recruiting_completed
    worker_scored
    worker_excluded
    offer_sent
    offer_accepted
    offer_declined
    offer_timeout
    next_worker_selected
  ].freeze

  # Source constants
  SOURCES = %w[algorithm manual_admin system].freeze

  # Validations
  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :source, presence: true, inclusion: { in: SOURCES }

  # Callbacks
  before_validation :set_default_source

  # Scopes
  scope :for_shift, ->(shift_id) { where(shift_id: shift_id) }
  scope :for_worker, ->(worker_id) { where(worker_profile_id: worker_id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :recent, -> { order(created_at: :desc) }
  scope :chronological, -> { order(created_at: :asc) }

  # Class methods for convenient logging
  class << self
    def log_recruiting_started(shift, details: {})
      create!(
        shift: shift,
        action: 'recruiting_started',
        details: details.merge(
          slots_total: shift.slots_total,
          slots_filled: shift.slots_filled,
          start_datetime: shift.start_datetime.iso8601
        )
      )
    end

    def log_recruiting_paused(shift, reason:, details: {})
      create!(
        shift: shift,
        action: 'recruiting_paused',
        details: details.merge(reason: reason)
      )
    end

    def log_recruiting_resumed(shift, details: {})
      create!(
        shift: shift,
        action: 'recruiting_resumed',
        details: details.merge(
          slots_available: shift.slots_available,
          start_datetime: shift.start_datetime.iso8601
        )
      )
    end

    def log_recruiting_completed(shift, reason:, details: {})
      create!(
        shift: shift,
        action: 'recruiting_completed',
        details: details.merge(
          reason: reason,
          slots_filled: shift.slots_filled,
          slots_total: shift.slots_total
        )
      )
    end

    def log_worker_scored(shift, worker_profile, score:, score_breakdown:, details: {})
      create!(
        shift: shift,
        worker_profile: worker_profile,
        action: 'worker_scored',
        details: details.merge(
          score: score,
          score_breakdown: score_breakdown
        )
      )
    end

    def log_worker_excluded(shift, worker_profile, reason:, details: {})
      create!(
        shift: shift,
        worker_profile: worker_profile,
        action: 'worker_excluded',
        details: details.merge(reason: reason)
      )
    end

    def log_offer_sent(shift, assignment, rank:, details: {})
      create!(
        shift: shift,
        worker_profile: assignment.worker_profile,
        shift_assignment: assignment,
        action: 'offer_sent',
        details: details.merge(
          rank: rank,
          algorithm_score: assignment.algorithm_score,
          distance_miles: assignment.distance_miles
        )
      )
    end

    def log_offer_accepted(shift, assignment, details: {})
      create!(
        shift: shift,
        worker_profile: assignment.worker_profile,
        shift_assignment: assignment,
        action: 'offer_accepted',
        details: details.merge(
          response_time_minutes: assignment.response_time_minutes,
          slots_filled: shift.reload.slots_filled,
          slots_total: shift.slots_total
        )
      )
    end

    def log_offer_declined(shift, assignment, reason:, details: {})
      create!(
        shift: shift,
        worker_profile: assignment.worker_profile,
        shift_assignment: assignment,
        action: 'offer_declined',
        details: details.merge(
          reason: reason,
          response_time_minutes: assignment.response_time_minutes
        )
      )
    end

    def log_offer_timeout(shift, assignment, details: {})
      create!(
        shift: shift,
        worker_profile: assignment.worker_profile,
        shift_assignment: assignment,
        action: 'offer_timeout',
        details: details.merge(
          timeout_minutes: 15,
          offer_sent_at: assignment.sms_sent_at&.iso8601
        )
      )
    end

    def log_next_worker_selected(shift, worker_profile, rank:, score:, details: {})
      create!(
        shift: shift,
        worker_profile: worker_profile,
        action: 'next_worker_selected',
        details: details.merge(
          rank: rank,
          score: score
        )
      )
    end
  end

  private

  def set_default_source
    self.source ||= 'algorithm'
  end
end
