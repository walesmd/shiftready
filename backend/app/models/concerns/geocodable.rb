# frozen_string_literal: true

# Geocodable concern for models with address fields
# Automatically geocodes addresses when they are created or updated
#
# Usage:
#   class MyModel < ApplicationRecord
#     include Geocodable
#
#     # Optional: customize which fields trigger geocoding
#     geocodable address_fields: %i[address_line_1 city state zip_code],
#                use_normalized_address: true
#   end
#
# Requirements:
#   - Model must have: address_line_1, city, state, zip_code
#   - Model should have: latitude, longitude (for storing coordinates)
#
module Geocodable
  extend ActiveSupport::Concern

  included do
    # Default configuration
    class_attribute :geocodable_address_fields, default: %i[address_line_1 city state zip_code]
    class_attribute :geocodable_use_normalized_address, default: false
    class_attribute :geocodable_prefix, default: nil

    after_commit :enqueue_geocoding, on: %i[create update]
  end

  class_methods do
    # Configure geocoding behavior for the model
    #
    # @param address_fields [Array<Symbol>] Fields that trigger geocoding when changed
    # @param use_normalized_address [Boolean] Whether to update address with normalized version from API
    # @param prefix [String, nil] Prefix for address fields (e.g., 'billing_' for billing_address_line_1)
    def geocodable(address_fields: %i[address_line_1 city state zip_code], use_normalized_address: false, prefix: nil)
      self.geocodable_address_fields = address_fields
      self.geocodable_use_normalized_address = use_normalized_address
      self.geocodable_prefix = prefix
    end
  end

  private

  def should_geocode?
    # Only geocode if:
    # 1. Record is valid (no validation errors)
    # 2. At least one address field has changed
    # 3. Required address fields are present
    errors.empty? && address_changed? && required_address_present?
  end

  def enqueue_geocoding
    return unless should_geocode?

    GeocodeAddressJob.perform_later(self.class.name, id)
  end

  def address_changed?
    geocodable_address_fields.any? { |field| send("#{field_with_prefix(field)}_changed?") }
  end

  def required_address_present?
    required_fields = geocodable_address_fields || %i[address_line_1 city state zip_code]
    required_fields.all? { |field| send(field_with_prefix(field)).present? }
  end

  def geocode_address
    result = GeocodingService.geocode(full_address)

    return unless result

    # Always update coordinates
    lat_field = "#{geocodable_prefix}latitude"
    lng_field = "#{geocodable_prefix}longitude"
    send("#{lat_field}=", result[:latitude]) if respond_to?("#{lat_field}=")
    send("#{lng_field}=", result[:longitude]) if respond_to?("#{lng_field}=")

    # Optionally update address with normalized version from API
    if geocodable_use_normalized_address
      update_normalized_address(result)
    end
  rescue StandardError => e
    Rails.logger.error("Failed to geocode #{self.class.name} (ID: #{id}): #{e.message}")
    # Don't fail the save if geocoding fails
  end

  def update_normalized_address(result)
    send("#{field_with_prefix(:address_line_1)}=", result[:address_line_1]) if result[:address_line_1].present?
    # Keep address_line_2 as is (user-provided)
    send("#{field_with_prefix(:city)}=", result[:city]) if result[:city].present?
    send("#{field_with_prefix(:state)}=", result[:state]) if result[:state].present?
    send("#{field_with_prefix(:zip_code)}=", result[:zip_code]) if result[:zip_code].present?
  end

  def field_with_prefix(field)
    geocodable_prefix ? "#{geocodable_prefix}#{field}" : field
  end

  # Build full address string for geocoding
  # Override this method in your model if you need custom address formatting
  def full_address
    parts = [
      send(field_with_prefix(:address_line_1)),
      send(field_with_prefix(:address_line_2)),
      send(field_with_prefix(:city)),
      send(field_with_prefix(:state)),
      send(field_with_prefix(:zip_code))
    ].compact

    parts.join(', ')
  end
end
