# frozen_string_literal: true

require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user, :worker, email: "worker@example.com", password: "password123")
    @worker_profile = @user.worker_profile
  end

  # ============================================================
  # GET /api/v1/auth/me
  # ============================================================

  test "returns current user profile when authenticated" do
    get "/api/v1/auth/me", headers: auth_headers(@user)

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal @user.id, json["user"]["id"]
    assert_equal @user.email, json["user"]["email"]
    assert_equal @user.role, json["user"]["role"]
  end

  test "returns unauthorized when not authenticated" do
    get "/api/v1/auth/me"

    assert_response :unauthorized
  end

  # ============================================================
  # PATCH /api/v1/auth/me - Email Update
  # ============================================================

  test "updates user email successfully" do
    new_email = "newemail@example.com"

    patch "/api/v1/auth/me",
          params: { user: { email: new_email } },
          headers: auth_headers(@user)

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "Profile updated successfully.", json["message"]
    assert_equal new_email, json["user"]["email"]
    assert_equal new_email, @user.reload.email
  end

  test "returns error for invalid email" do
    patch "/api/v1/auth/me",
          params: { user: { email: "invalid-email" } },
          headers: auth_headers(@user)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["errors"].present?
  end

  # ============================================================
  # PATCH /api/v1/auth/me - Password Change
  # ============================================================

  test "updates password successfully with correct current password" do
    patch "/api/v1/auth/me",
          params: {
            user: {
              current_password: "password123",
              password: "newpassword456",
              password_confirmation: "newpassword456"
            }
          },
          headers: auth_headers(@user)

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "Password updated successfully.", json["message"]

    # Verify user can login with new password
    @user.reload
    assert @user.valid_password?("newpassword456")
    refute @user.valid_password?("password123")
  end

  test "regenerates JTI after password change" do
    old_jti = @user.jti

    patch "/api/v1/auth/me",
          params: {
            user: {
              current_password: "password123",
              password: "newpassword456",
              password_confirmation: "newpassword456"
            }
          },
          headers: auth_headers(@user)

    assert_response :ok
    @user.reload
    assert_not_equal old_jti, @user.jti
  end

  test "returns error when current password is incorrect" do
    patch "/api/v1/auth/me",
          params: {
            user: {
              current_password: "wrongpassword",
              password: "newpassword456",
              password_confirmation: "newpassword456"
            }
          },
          headers: auth_headers(@user)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "Current password is incorrect", json["error"]

    # Verify password was not changed
    @user.reload
    assert @user.valid_password?("password123")
  end

  test "returns error when current password is not provided" do
    patch "/api/v1/auth/me",
          params: {
            user: {
              password: "newpassword456",
              password_confirmation: "newpassword456"
            }
          },
          headers: auth_headers(@user)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "Current password is required", json["error"]
  end

  test "returns error when new password is not provided" do
    patch "/api/v1/auth/me",
          params: {
            user: {
              current_password: "password123",
              password_confirmation: "newpassword456"
            }
          },
          headers: auth_headers(@user)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "New password and confirmation are required", json["error"]
  end

  test "returns error when password confirmation is not provided" do
    patch "/api/v1/auth/me",
          params: {
            user: {
              current_password: "password123",
              password: "newpassword456"
            }
          },
          headers: auth_headers(@user)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "New password and confirmation are required", json["error"]
  end

  test "returns error when password and confirmation do not match" do
    patch "/api/v1/auth/me",
          params: {
            user: {
              current_password: "password123",
              password: "newpassword456",
              password_confirmation: "differentpassword"
            }
          },
          headers: auth_headers(@user)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["errors"].present?
    assert_includes json["errors"].join(" "), "Password confirmation"
  end

  test "returns error when new password is too short" do
    patch "/api/v1/auth/me",
          params: {
            user: {
              current_password: "password123",
              password: "12345",
              password_confirmation: "12345"
            }
          },
          headers: auth_headers(@user)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["errors"].present?
    assert_includes json["errors"].join(" "), "Password is too short"
  end

  test "returns unauthorized when not authenticated for password change" do
    patch "/api/v1/auth/me",
          params: {
            user: {
              current_password: "password123",
              password: "newpassword456",
              password_confirmation: "newpassword456"
            }
          }

    assert_response :unauthorized
  end
end
