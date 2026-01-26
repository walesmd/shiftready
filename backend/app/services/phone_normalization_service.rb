# frozen_string_literal: true

# Service for normalizing phone numbers to E.164 format
# Handles US phone numbers and ensures consistent storage format
#
# E.164 format: +1XXXXXXXXXX (country code + 10 digits)
#
# Supports input formats:
#   - (210) 555-0123
#   - 210-555-0123
#   - 210.555.0123
#   - 2105550123
#   - 12105550123
#   - +12105550123
class PhoneNormalizationService
  class InvalidPhoneNumberError < StandardError; end

  # Normalizes a phone number to E.164 format (+1XXXXXXXXXX)
  #
  # @param phone_number [String] Raw phone number input
  # @return [String, nil] Normalized phone number in E.164 format, or nil if invalid
  def self.normalize(phone_number)
    return nil if phone_number.blank?

    new.normalize(phone_number)
  end

  def normalize(phone_number)
    # Strip all non-digit characters
    digits = phone_number.to_s.gsub(/\D/, '')

    # Handle different digit counts
    case digits.length
    when 10
      # 10 digits: assume US number, add +1
      "+1#{digits}"
    when 11
      # 11 digits: check if it starts with 1 (US country code)
      if digits.start_with?('1')
        "+#{digits}"
      else
        # Invalid: 11 digits but doesn't start with 1
        nil
      end
    else
      # Invalid: not 10 or 11 digits
      nil
    end
  rescue StandardError => e
    Rails.logger.error("Phone normalization failed for input '#{phone_number}': #{e.message}")
    nil
  end

  # Validates if a phone number can be normalized
  #
  # @param phone_number [String] Raw phone number input
  # @return [Boolean] true if the phone number can be normalized
  def self.valid?(phone_number)
    normalize(phone_number).present?
  end

  # Formats a normalized phone number for display
  # Converts +12105550123 to (210) 555-0123
  #
  # @param phone_number [String] Normalized phone number in E.164 format
  # @return [String, nil] Formatted phone number for display
  def self.format_display(phone_number)
    return nil if phone_number.blank?

    # Strip all non-digit characters
    digits = phone_number.gsub(/\D/, '')

    # Should be 11 digits starting with 1 (US format)
    return phone_number unless digits.length == 11 && digits.start_with?('1')

    # Remove country code and format
    local_digits = digits[1..10]
    "(#{local_digits[0..2]}) #{local_digits[3..5]}-#{local_digits[6..9]}"
  rescue StandardError
    phone_number
  end
end
