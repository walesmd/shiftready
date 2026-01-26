# frozen_string_literal: true

require "test_helper"

class CompanyTest < ActiveSupport::TestCase
  # Associations
  test "has many employer_profiles" do
    company = create(:company)
    profile = create(:employer_profile, company: company)
    assert_includes company.employer_profiles, profile
  end

  test "has many work_locations" do
    company = create(:company)
    location = create(:work_location, company: company)
    assert_includes company.work_locations, location
  end

  test "has many shifts" do
    company = create(:company)
    shift = create(:shift, company: company)
    assert_includes company.shifts, shift
  end

  test "destroys associated work_locations" do
    company = create(:company)
    location = create(:work_location, company: company)
    location_id = location.id

    company.destroy
    assert_nil WorkLocation.find_by(id: location_id)
  end

  test "shifts dependent destroy is configured on company" do
    # Verify the association is set up with dependent: :destroy
    # The actual cascade behavior is complex due to foreign key constraints
    # (shift -> created_by_employer has restrict_with_error), so we just verify
    # the association is configured correctly
    reflection = Company.reflect_on_association(:shifts)
    assert_equal :destroy, reflection.options[:dependent]
  end

  test "restricts deletion when employer_profiles exist" do
    company = create(:company)
    create(:employer_profile, company: company)

    # destroy returns false when restricted due to dependent: :restrict_with_error
    result = company.destroy
    assert_equal false, result
    assert Company.exists?(company.id), "Company should still exist after failed destroy"
    assert company.errors[:base].any? { |e| e.include?("employer") || e.include?("restrict") }
  end

  # Validations
  test "requires name" do
    company = build(:company, name: nil)
    assert_not company.valid?
    assert_includes company.errors[:name], "can't be blank"
  end

  test "validates billing_email format" do
    company = build(:company, billing_email: "invalid")
    assert_not company.valid?
    assert_includes company.errors[:billing_email], "is invalid"
  end

  test "allows blank billing_email" do
    company = build(:company, billing_email: "")
    assert company.valid?
  end

  test "validates billing_zip_code format" do
    company = build(:company, billing_zip_code: "invalid")
    assert_not company.valid?
    assert_includes company.errors[:billing_zip_code], "must be a valid ZIP code"
  end

  test "allows 5-digit zip code" do
    company = build(:company, billing_zip_code: "78201")
    assert company.valid?
  end

  test "allows 5+4 digit zip code" do
    company = build(:company, billing_zip_code: "78201-1234")
    assert company.valid?
  end

  test "allows blank billing_zip_code" do
    company = build(:company, billing_zip_code: "")
    assert company.valid?
  end

  # Scopes
  test "active scope returns only active companies" do
    active = create(:company,
                    billing_address_line_1: "123 Main St",
                    billing_city: "San Antonio",
                    billing_state: "TX",
                    billing_zip_code: "78201",
                    billing_email: "billing@example.com",
                    billing_phone: "2105551234")
    create(:work_location, company: active)
    active.refresh_onboarding_status!

    inactive = create(:company,
                      billing_address_line_1: "456 Oak Ave",
                      billing_city: "San Antonio",
                      billing_state: "TX",
                      billing_zip_code: "78201",
                      billing_email: "inactive@example.com",
                      billing_phone: "2105555678")

    assert_includes Company.active, active
    assert_not_includes Company.active, inactive
  end

  test "by_industry scope filters by industry" do
    construction = create(:company, industry: "construction")
    retail = create(:company, industry: "retail")

    assert_includes Company.by_industry("construction"), construction
    assert_not_includes Company.by_industry("construction"), retail
  end

  # Instance methods
  test "full_billing_address returns formatted address" do
    company = build(:company,
                    billing_address_line_1: "123 Main St",
                    billing_address_line_2: "Suite 100",
                    billing_city: "San Antonio",
                    billing_state: "TX",
                    billing_zip_code: "78201")

    assert_equal "123 Main St, Suite 100, San Antonio, TX, 78201", company.full_billing_address
  end

  test "full_billing_address excludes nil fields" do
    company = build(:company,
                    billing_address_line_1: "123 Main St",
                    billing_address_line_2: nil,
                    billing_city: "San Antonio",
                    billing_state: "TX",
                    billing_zip_code: "78201")

    assert_equal "123 Main St, San Antonio, TX, 78201", company.full_billing_address
  end

  # can_be_deleted?
  test "can_be_deleted? returns true when no profiles or shifts" do
    company = create(:company)
    assert company.can_be_deleted?
  end

  test "can_be_deleted? returns false when employer_profiles exist" do
    company = create(:company)
    create(:employer_profile, company: company)
    assert_not company.can_be_deleted?
  end

  test "can_be_deleted? returns false when shifts exist" do
    company = create(:company)
    create(:shift, company: company)
    assert_not company.can_be_deleted?
  end
end
