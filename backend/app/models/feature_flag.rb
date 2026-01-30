# frozen_string_literal: true

class FeatureFlag < ApplicationRecord
  VALID_ACTIONS = %w[created updated archived restored].freeze

  has_many :audit_logs, class_name: "FeatureFlagAuditLog", dependent: :destroy

  validates :key, presence: true,
                  uniqueness: { case_sensitive: false },
                  format: { with: /\A[a-z][a-z0-9_]*\z/, message: "must be lowercase snake_case starting with a letter" }
  validates :value, presence: true, allow_blank: false, unless: -> { value == false }

  scope :active, -> { where(archived: false) }
  scope :archived, -> { where(archived: true) }
  scope :boolean_flags, -> { where("jsonb_typeof(value) = 'boolean'") }

  after_commit :invalidate_cache

  class << self
    def get(key, archived: false)
      cache_key = cache_key_for(key, archived: archived)
      Rails.cache.fetch(cache_key) do
        find_by(key: key.to_s, archived: archived)
      end
    end

    def enabled?(key)
      flag = get(key)
      return false unless flag

      flag.enabled?
    end

    def disabled?(key)
      !enabled?(key)
    end

    def value(key)
      flag = get(key)
      return nil unless flag

      flag.value
    end

    def cache_key_for(key, archived: false)
      "feature_flag/#{key}/archived:#{archived}"
    end
  end

  def enabled?
    return false if archived?
    return value if boolean?

    value.present?
  end

  def disabled?
    !enabled?
  end

  def boolean?
    value.is_a?(TrueClass) || value.is_a?(FalseClass)
  end

  def value_type
    case value
    when TrueClass, FalseClass then "boolean"
    when String then "string"
    when Integer, Float then "number"
    when Array then "array"
    when Hash then "object"
    else "unknown"
    end
  end

  def archive!(user:)
    return false if archived?

    transaction do
      update!(archived: true)
      audit_logs.create!(
        user: user,
        action: "archived",
        previous_value: { archived: false },
        new_value: { archived: true }
      )
    end
    true
  end

  def restore!(user:)
    return false unless archived?

    transaction do
      update!(archived: false)
      audit_logs.create!(
        user: user,
        action: "restored",
        previous_value: { archived: true },
        new_value: { archived: false }
      )
    end
    true
  end

  private

  def invalidate_cache
    # Clear both archived states since a flag update could affect either lookup
    Rails.cache.delete(self.class.cache_key_for(key, archived: false))
    Rails.cache.delete(self.class.cache_key_for(key, archived: true))
  end
end
