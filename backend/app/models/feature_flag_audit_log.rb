# frozen_string_literal: true

class FeatureFlagAuditLog < ApplicationRecord
  ACTIONS = %w[created updated archived restored].freeze

  belongs_to :feature_flag
  belongs_to :user

  validates :action, presence: true, inclusion: { in: ACTIONS }

  scope :recent, -> { order(created_at: :desc) }

  class << self
    def log_created(feature_flag:, user:, value:)
      create!(
        feature_flag: feature_flag,
        user: user,
        action: "created",
        previous_value: nil,
        new_value: { key: feature_flag.key, value: value }
      )
    end

    def log_updated(feature_flag:, user:, previous_value:, new_value:)
      create!(
        feature_flag: feature_flag,
        user: user,
        action: "updated",
        previous_value: previous_value,
        new_value: new_value
      )
    end

    def log_archived(feature_flag:, user:)
      create!(
        feature_flag: feature_flag,
        user: user,
        action: "archived",
        previous_value: { archived: false },
        new_value: { archived: true }
      )
    end

    def log_restored(feature_flag:, user:)
      create!(
        feature_flag: feature_flag,
        user: user,
        action: "restored",
        previous_value: { archived: true },
        new_value: { archived: false }
      )
    end
  end
end
