# frozen_string_literal: true

class FeatureService
  CACHE_TTL = 5.minutes

  class << self
    def enabled?(key, for_role: nil)
      flag_value = cached_value(key)
      return false if flag_value.nil?

      # Handle role-based hash values
      if flag_value.is_a?(Hash) && for_role.present?
        role_key = for_role.to_s
        return flag_value[role_key] == true if flag_value.key?(role_key)

        return false
      end

      # Handle boolean values
      return flag_value if flag_value.is_a?(TrueClass) || flag_value.is_a?(FalseClass)

      # Non-boolean values are considered enabled if present
      flag_value.present?
    end

    def disabled?(key, for_role: nil)
      !enabled?(key, for_role: for_role)
    end

    def value(key)
      cached_value(key)
    end

    def invalidate_cache(key)
      Rails.cache.delete(cache_key(key))
    end

    def invalidate_all_caches
      FeatureFlag.pluck(:key).each do |key|
        invalidate_cache(key)
      end
    end

    private

    def cached_value(key)
      Rails.cache.fetch(cache_key(key), expires_in: CACHE_TTL) do
        flag = FeatureFlag.get(key)
        flag&.value
      end
    end

    def cache_key(key)
      "feature_flag/#{key}"
    end
  end
end
