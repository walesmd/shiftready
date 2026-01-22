# frozen_string_literal: true

require "test_helper"

class Api::V1::Auth::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  def registration_params(overrides = {})
    {
      user: {
        email: "employer@example.com",
        password: "password123",
        password_confirmation: "password123",
        role: "employer"
      }
    }.deep_merge(overrides)
  end

  # ============================================================
  # EMPLOYER REGISTRATION
  # ============================================================

  test "creates employer user with company and profile" do
    params = registration_params(
      user: {
        company_attributes: {
          name: "Sunrise Staffing",
          industry: "Hospitality",
          billing_address_line_1: "123 Main St",
          billing_city: "San Antonio",
          billing_state: "TX",
          billing_zip_code: "78205"
        },
        employer_profile_attributes: {
          first_name: "Alex",
          last_name: "Johnson",
          title: "Operations Manager",
          phone: "+12105550123",
          terms_accepted_at: Time.current.iso8601,
          msa_accepted_at: Time.current.iso8601
        }
      }
    )

    assert_difference ["User.count", "Company.count", "EmployerProfile.count"], 1 do
      post "/api/v1/auth/register", params: params
    end

    assert_response :created
    user = User.find_by(email: "employer@example.com")
    assert user.employer?
    assert user.employer_profile.present?
    assert_equal "Sunrise Staffing", user.employer_profile.company.name
  end

  test "creates employer with minimal required fields" do
    assert_difference ["User.count", "Company.count", "EmployerProfile.count"], 1 do
      post "/api/v1/auth/register", params: registration_params
    end

    assert_response :created
    user = User.find_by(email: "employer@example.com")
    assert user.employer?
    assert user.employer_profile.present?
    assert user.employer_profile.company.present?
  end

  test "returns error for invalid employer registration" do
    params = registration_params(user: { email: "not-an-email" })

    assert_no_difference ["User.count", "Company.count", "EmployerProfile.count"] do
      post "/api/v1/auth/register", params: params
    end

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert json["errors"].present?
  end

  test "returns error for duplicate email" do
    create(:user, email: "employer@example.com")

    assert_no_difference ["User.count", "Company.count", "EmployerProfile.count"] do
      post "/api/v1/auth/register", params: registration_params
    end

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert json["errors"].present?
  end

  test "returns error for password mismatch" do
    params = registration_params(user: { password_confirmation: "password456" })

    assert_no_difference ["User.count", "Company.count", "EmployerProfile.count"] do
      post "/api/v1/auth/register", params: params
    end

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert json["errors"].present?
  end

  # ============================================================
  # WORKER REGISTRATION
  # ============================================================

  test "creates worker user" do
    params = {
      user: {
        email: "worker@example.com",
        password: "password123",
        password_confirmation: "password123",
        role: "worker"
      }
    }

    assert_difference "User.count", 1 do
      post "/api/v1/auth/register", params: params
    end

    assert_response :created
    user = User.find_by(email: "worker@example.com")
    assert user.worker?
    assert_nil user.employer_profile
    assert_nil user.worker_profile
  end

  # ============================================================
  # RESPONSE FORMAT
  # ============================================================

  test "returns user data in response" do
    post "/api/v1/auth/register", params: registration_params

    assert_response :created
    json = response.parsed_body
    assert_equal "Signed up successfully.", json["message"]
    assert_equal "employer", json.dig("user", "role")
    assert_equal "employer@example.com", json.dig("user", "email")
  end
end
