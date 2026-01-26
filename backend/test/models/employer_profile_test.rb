# frozen_string_literal: true

require "test_helper"

class EmployerProfileTest < ActiveSupport::TestCase
  # Associations
  test "belongs to user" do
    profile = create(:employer_profile)
    assert profile.user.present?
    assert profile.user.employer?
  end

  test "belongs to company" do
    profile = create(:employer_profile)
    assert profile.company.present?
  end

  test "has many shifts through created_by_employer" do
    company = create(:company)
    profile = create(:employer_profile, :onboarded, company: company)
    work_location = create(:work_location, company: company)
    shift = create(:shift, company: company, work_location: work_location, created_by_employer: profile)
    assert_includes profile.shifts, shift
  end

  # Validations
  test "requires first_name" do
    profile = build(:employer_profile, first_name: nil)
    assert_not profile.valid?
    assert_includes profile.errors[:first_name], "can't be blank"
  end

  test "requires last_name" do
    profile = build(:employer_profile, last_name: nil)
    assert_not profile.valid?
    assert_includes profile.errors[:last_name], "can't be blank"
  end

  test "requires phone" do
    profile = build(:employer_profile, phone: nil)
    assert_not profile.valid?
    assert_includes profile.errors[:phone], "can't be blank"
  end

  test "validates phone format" do
    profile = build(:employer_profile, phone: "invalid")
    assert_not profile.valid?
    assert_includes profile.errors[:phone], "must be a valid phone number"
  end

  # Scopes
  test "onboarded scope returns only onboarded profiles" do
    onboarded = create(:employer_profile, :onboarded)
    not_onboarded = create(:employer_profile, onboarding_completed: false)

    assert_includes EmployerProfile.onboarded, onboarded
    assert_not_includes EmployerProfile.onboarded, not_onboarded
  end

  test "can_post scope returns profiles that can post shifts" do
    can_post = create(:employer_profile, can_post_shifts: true)
    cannot_post = create(:employer_profile, can_post_shifts: false)

    assert_includes EmployerProfile.can_post, can_post
    assert_not_includes EmployerProfile.can_post, cannot_post
  end

  test "can_approve scope returns profiles that can approve timesheets" do
    can_approve = create(:employer_profile, can_approve_timesheets: true)
    cannot_approve = create(:employer_profile, can_approve_timesheets: false)

    assert_includes EmployerProfile.can_approve, can_approve
    assert_not_includes EmployerProfile.can_approve, cannot_approve
  end

  test "billing_contacts scope returns billing contact profiles" do
    billing = create(:employer_profile, :billing_contact)
    not_billing = create(:employer_profile, is_billing_contact: false)

    assert_includes EmployerProfile.billing_contacts, billing
    assert_not_includes EmployerProfile.billing_contacts, not_billing
  end

  test "for_company scope filters by company" do
    company1 = create(:company)
    company2 = create(:company)
    profile1 = create(:employer_profile, company: company1)
    profile2 = create(:employer_profile, company: company2)

    assert_includes EmployerProfile.for_company(company1.id), profile1
    assert_not_includes EmployerProfile.for_company(company1.id), profile2
  end

  # Instance methods
  test "full_name returns first and last name" do
    profile = build(:employer_profile, first_name: "Jane", last_name: "Smith")
    assert_equal "Jane Smith", profile.full_name
  end

  # Permission methods
  test "can_create_shifts? returns true when onboarded and has permission" do
    profile = create(:employer_profile, onboarding_completed: true, can_post_shifts: true)
    assert profile.can_create_shifts?
  end

  test "can_create_shifts? returns false when not onboarded" do
    profile = create(:employer_profile, onboarding_completed: false, can_post_shifts: true)
    assert_not profile.can_create_shifts?
  end

  test "can_create_shifts? returns false without permission" do
    profile = create(:employer_profile, onboarding_completed: true, can_post_shifts: false)
    assert_not profile.can_create_shifts?
  end

  test "can_approve_shift_timesheets? returns true when onboarded and has permission" do
    profile = create(:employer_profile, :can_approve)
    assert profile.can_approve_shift_timesheets?
  end

  test "can_approve_shift_timesheets? returns false when not onboarded" do
    profile = create(:employer_profile, onboarding_completed: false, can_approve_timesheets: true)
    assert_not profile.can_approve_shift_timesheets?
  end

  test "can_approve_shift_timesheets? returns false without permission" do
    profile = create(:employer_profile, onboarding_completed: true, can_approve_timesheets: false)
    assert_not profile.can_approve_shift_timesheets?
  end

  # Phone display formatting
  test "phone_display returns formatted phone number" do
    profile = build(:employer_profile, phone: "+12105551234")
    assert_equal "(210) 555-1234", profile.phone_display
  end

  test "phone_display handles nil phone gracefully" do
    profile = build(:employer_profile, phone: nil)
    assert_nil profile.phone_display
  end
end
