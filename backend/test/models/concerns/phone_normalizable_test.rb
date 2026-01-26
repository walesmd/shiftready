# frozen_string_literal: true

require "test_helper"

class PhoneNormalizableTest < ActiveSupport::TestCase
  # Test with WorkerProfile which has 'phone' field
  test "automatically normalizes phone number on WorkerProfile creation" do
    worker = build(:worker_profile, phone: "(210) 555-1234")

    assert worker.valid?
    assert_equal "+12105551234", worker.phone
  end

  test "automatically normalizes phone number on WorkerProfile update" do
    worker = create(:worker_profile, phone: "+12105551234")

    worker.phone = "210-555-9999"
    worker.valid?

    assert_equal "+12105559999", worker.phone
  end

  test "handles 11-digit phone number with 1 prefix on WorkerProfile" do
    worker = build(:worker_profile, phone: "1 (210) 555-1234")

    assert worker.valid?
    assert_equal "+12105551234", worker.phone
  end

  test "handles already normalized phone number on WorkerProfile" do
    worker = build(:worker_profile, phone: "+12105551234")

    assert worker.valid?
    assert_equal "+12105551234", worker.phone
  end

  test "leaves invalid phone number unchanged for validation to catch" do
    worker = build(:worker_profile, phone: "123")

    # Phone should not be normalized (stays as "123")
    # Validation should fail
    assert_not worker.valid?
    assert_includes worker.errors[:phone], "must be a valid phone number"
  end

  test "handles blank phone number gracefully on WorkerProfile" do
    worker = build(:worker_profile, phone: "")

    # Should not try to normalize blank value
    # Validation should catch presence error
    assert_not worker.valid?
    assert_includes worker.errors[:phone], "can't be blank"
  end

  # Test with EmployerProfile which also has 'phone' field
  test "automatically normalizes phone number on EmployerProfile creation" do
    employer = build(:employer_profile, phone: "(210) 555-5678")

    assert employer.valid?
    assert_equal "+12105555678", employer.phone
  end

  test "automatically normalizes phone number on EmployerProfile update" do
    employer = create(:employer_profile, phone: "+12105555678")

    employer.phone = "210.555.9999"
    employer.valid?

    assert_equal "+12105559999", employer.phone
  end

  # Test with Message which has 'from_phone' and 'to_phone' fields
  test "automatically normalizes from_phone and to_phone on Message" do
    worker = create(:worker_profile, :onboarded)

    message = build(:message,
                    messageable: worker,
                    direction: :outbound,
                    channel: :sms,
                    from_phone: "(210) 555-0001",
                    to_phone: "(210) 555-0002")

    assert message.valid?
    assert_equal "+12105550001", message.from_phone
    assert_equal "+12105550002", message.to_phone
  end

  test "normalizes only specified phone fields in Message" do
    worker = create(:worker_profile, :onboarded)

    message = build(:message,
                    messageable: worker,
                    direction: :outbound,
                    channel: :sms,
                    from_phone: "210-555-0001",
                    to_phone: "12105550002")

    assert message.valid?
    assert_equal "+12105550001", message.from_phone
    assert_equal "+12105550002", message.to_phone
  end

  test "handles Message with non-SMS channel without phone normalization issues" do
    worker = create(:worker_profile, :onboarded)

    # Email channel doesn't require phone numbers
    message = build(:message,
                    messageable: worker,
                    direction: :outbound,
                    channel: :email,
                    from_phone: nil,
                    to_phone: nil)

    assert message.valid?
  end

  # Test that normalization happens before validation
  test "normalization occurs before validation runs" do
    worker = build(:worker_profile, phone: "(210) 555-1234")

    # Before validation is run, phone should still be formatted
    assert_equal "(210) 555-1234", worker.phone

    # Run validation
    worker.valid?

    # After validation (which triggers before_validation), phone should be normalized
    assert_equal "+12105551234", worker.phone
  end

  test "normalization allows valid formats to pass validation" do
    # All these formats should normalize and pass validation
    valid_formats = [
      "(210) 555-0123",
      "210-555-0123",
      "210.555.0123",
      "2105550123",
      "12105550123",
      "+12105550123"
    ]

    valid_formats.each do |format|
      worker = build(:worker_profile, phone: format)
      assert worker.valid?, "Phone format '#{format}' should be valid after normalization"
      assert_equal "+12105550123", worker.phone, "Phone format '#{format}' should normalize to +12105550123"
    end
  end

  test "invalid phone numbers fail validation even with normalization" do
    invalid_formats = [
      "123",              # Too short
      "12345678901234",   # Too long
      "abc-def-ghij",     # No digits
      "22105550123"       # 11 digits but doesn't start with 1
    ]

    invalid_formats.each do |format|
      worker = build(:worker_profile, phone: format)
      assert_not worker.valid?, "Phone format '#{format}' should be invalid"
      assert_includes worker.errors[:phone], "must be a valid phone number"
    end
  end

  # Test uniqueness constraint with normalization
  test "uniqueness validation works with normalized phone numbers" do
    # Create first worker with formatted number
    create(:worker_profile, phone: "(210) 555-1234")

    # Try to create second worker with same number but different format
    worker2 = build(:worker_profile, phone: "210-555-1234")

    # Should fail uniqueness validation because both normalize to same value
    assert_not worker2.valid?
    assert_includes worker2.errors[:phone], "has already been taken"
  end

  test "uniqueness works across different formats of same phone number" do
    create(:worker_profile, phone: "2105551234")

    # All these should fail uniqueness
    duplicate_formats = [
      "(210) 555-1234",
      "210-555-1234",
      "+12105551234",
      "1-210-555-1234"
    ]

    duplicate_formats.each do |format|
      worker = build(:worker_profile, phone: format)
      assert_not worker.valid?, "Phone '#{format}' should fail uniqueness"
      assert_includes worker.errors[:phone], "has already been taken"
    end
  end
end
