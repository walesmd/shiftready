# frozen_string_literal: true

# PhoneNormalizable concern for models with phone number fields
# Automatically normalizes phone numbers to E.164 format before validation
#
# Usage:
#   class MyModel < ApplicationRecord
#     include PhoneNormalizable
#
#     # Optional: customize which fields to normalize
#     normalize_phone_fields :phone, :mobile, :emergency_contact_phone
#   end
#
# Default behavior:
#   - Normalizes fields named: phone, phone_number, mobile, from_phone, to_phone
#   - Runs before validation
#   - Converts to E.164 format: +1XXXXXXXXXX
#
# Requirements:
#   - Model must have one or more phone number fields (string type)
#
module PhoneNormalizable
  extend ActiveSupport::Concern

  included do
    # Default phone field names to normalize
    class_attribute :normalizable_phone_fields,
                    default: %i[phone phone_number mobile from_phone to_phone]

    before_validation :normalize_phone_numbers
  end

  class_methods do
    # Configure which phone fields to normalize for the model
    #
    # @param fields [Array<Symbol>] Fields containing phone numbers to normalize
    #
    # Example:
    #   normalize_phone_fields :phone, :emergency_contact_phone
    def normalize_phone_fields(*fields)
      self.normalizable_phone_fields = fields
    end
  end

  private

  def normalize_phone_numbers
    # Get list of phone fields that exist in this model
    phone_fields = normalizable_phone_fields.select { |field| respond_to?(field) }

    phone_fields.each do |field|
      current_value = send(field)
      next if current_value.blank?

      # Normalize the phone number
      normalized = PhoneNormalizationService.normalize(current_value)

      # Update the field with normalized value if normalization succeeded
      if normalized.present?
        send("#{field}=", normalized)
      end
      # If normalization failed (returns nil), leave the original value
      # so that model validations can catch and report the error
    end
  end
end
