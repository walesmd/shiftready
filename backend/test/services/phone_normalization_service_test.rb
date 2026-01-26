# frozen_string_literal: true

require "test_helper"

class PhoneNormalizationServiceTest < ActiveSupport::TestCase
  # Basic normalization tests
  test "normalizes 10-digit phone number by adding +1" do
    result = PhoneNormalizationService.normalize("2105550123")
    assert_equal "+12105550123", result
  end

  test "normalizes phone number with parentheses and dashes" do
    result = PhoneNormalizationService.normalize("(210) 555-0123")
    assert_equal "+12105550123", result
  end

  test "normalizes phone number with dots" do
    result = PhoneNormalizationService.normalize("210.555.0123")
    assert_equal "+12105550123", result
  end

  test "normalizes phone number with spaces" do
    result = PhoneNormalizationService.normalize("210 555 0123")
    assert_equal "+12105550123", result
  end

  test "normalizes phone number with mixed formatting" do
    result = PhoneNormalizationService.normalize("(210)-555.0123")
    assert_equal "+12105550123", result
  end

  # 11-digit numbers starting with 1
  test "normalizes 11-digit number starting with 1" do
    result = PhoneNormalizationService.normalize("12105550123")
    assert_equal "+12105550123", result
  end

  test "normalizes 11-digit number with 1 and formatting" do
    result = PhoneNormalizationService.normalize("1 (210) 555-0123")
    assert_equal "+12105550123", result
  end

  # Already normalized numbers
  test "handles already normalized number with plus sign" do
    result = PhoneNormalizationService.normalize("+12105550123")
    assert_equal "+12105550123", result
  end

  test "handles already normalized number with plus and formatting" do
    result = PhoneNormalizationService.normalize("+1 (210) 555-0123")
    assert_equal "+12105550123", result
  end

  # Invalid phone numbers
  test "returns nil for phone number with too few digits" do
    result = PhoneNormalizationService.normalize("123456789")
    assert_nil result
  end

  test "returns nil for phone number with too many digits" do
    result = PhoneNormalizationService.normalize("123456789012")
    assert_nil result
  end

  test "returns nil for 11-digit number not starting with 1" do
    result = PhoneNormalizationService.normalize("22105550123")
    assert_nil result
  end

  test "returns nil for empty string" do
    result = PhoneNormalizationService.normalize("")
    assert_nil result
  end

  test "returns nil for nil input" do
    result = PhoneNormalizationService.normalize(nil)
    assert_nil result
  end

  test "returns nil for non-numeric string" do
    result = PhoneNormalizationService.normalize("not a phone number")
    assert_nil result
  end

  # Edge cases
  test "handles phone number with unicode characters" do
    result = PhoneNormalizationService.normalize("(210) 555‐0123") # Unicode dash
    assert_equal "+12105550123", result
  end

  test "handles phone number with extension marker removed" do
    # Extensions are stripped out, just get the base 10 digits
    result = PhoneNormalizationService.normalize("210-555-0123 ext 123")
    # This has 12 digits total (2105550123123), so it should return nil
    assert_nil result
  end

  test "handles phone number with leading zeros after country code" do
    # Not a valid US number (area codes don't start with 0)
    result = PhoneNormalizationService.normalize("(010) 555-0123")
    # This is still 10 digits, so it will normalize
    assert_equal "+10105550123", result
  end

  # Validation tests
  test "valid? returns true for normalizable phone number" do
    assert PhoneNormalizationService.valid?("2105550123")
    assert PhoneNormalizationService.valid?("(210) 555-0123")
    assert PhoneNormalizationService.valid?("+12105550123")
  end

  test "valid? returns false for invalid phone number" do
    assert_not PhoneNormalizationService.valid?("123")
    assert_not PhoneNormalizationService.valid?("not a phone")
    assert_not PhoneNormalizationService.valid?(nil)
  end

  # Display formatting tests
  test "format_display converts E.164 to display format" do
    result = PhoneNormalizationService.format_display("+12105550123")
    assert_equal "(210) 555-0123", result
  end

  test "format_display handles E.164 without plus sign" do
    result = PhoneNormalizationService.format_display("12105550123")
    assert_equal "(210) 555-0123", result
  end

  test "format_display returns original if not valid format" do
    result = PhoneNormalizationService.format_display("invalid")
    assert_equal "invalid", result
  end

  test "format_display returns nil for nil input" do
    result = PhoneNormalizationService.format_display(nil)
    assert_nil result
  end

  test "format_display returns nil for empty string" do
    result = PhoneNormalizationService.format_display("")
    assert_nil result
  end

  test "format_display handles 10-digit number" do
    # 10-digit numbers aren't in E.164 format (which requires country code)
    result = PhoneNormalizationService.format_display("2105550123")
    # format_display expects 11-digit E.164, so 10 digits returns as-is
    assert_equal "2105550123", result
  end
end
