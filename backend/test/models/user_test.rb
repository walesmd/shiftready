# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  # Associations
  test "has one worker_profile" do
    user = create(:user, :worker, :without_profile_callback)
    profile = create(:worker_profile, user: user)
    assert_equal profile, user.worker_profile
  end

  test "has one employer_profile" do
    user = create(:user, :employer, :without_profile_callback)
    profile = create(:employer_profile, user: user)
    assert_equal profile, user.employer_profile
  end

  test "destroys associated worker_profile when destroyed" do
    user = create(:user, :worker, :without_profile_callback)
    profile = create(:worker_profile, user: user)
    profile_id = profile.id

    user.destroy
    assert_nil WorkerProfile.find_by(id: profile_id)
  end

  test "destroys associated employer_profile when destroyed" do
    user = create(:user, :employer, :without_profile_callback)
    profile = create(:employer_profile, user: user)
    profile_id = profile.id

    user.destroy
    assert_nil EmployerProfile.find_by(id: profile_id)
  end

  # Validations
  test "requires email" do
    user = build(:user, email: nil)
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "requires unique email" do
    create(:user, email: "test@example.com")
    user = build(:user, email: "test@example.com")
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "requires valid email format" do
    user = build(:user, email: "invalid-email")
    assert_not user.valid?
    assert_includes user.errors[:email], "is invalid"
  end

  test "requires password" do
    user = build(:user, password: nil)
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "requires password minimum length" do
    user = build(:user, password: "short", password_confirmation: "short")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 6 characters)"
  end

  test "requires role" do
    user = build(:user, role: nil)
    assert_not user.valid?
    assert_includes user.errors[:role], "can't be blank"
  end

  # Enums
  test "role enum has correct values" do
    assert_equal({ "worker" => 0, "employer" => 1, "admin" => 2 }, User.roles)
  end

  test "user can be a worker" do
    user = create(:user, :worker, :without_profile_callback)
    assert user.worker?
    assert_not user.employer?
    assert_not user.admin?
  end

  test "user can be an employer" do
    user = create(:user, :employer, :without_profile_callback)
    assert user.employer?
    assert_not user.worker?
    assert_not user.admin?
  end

  test "user can be an admin" do
    user = create(:user, :admin, :without_profile_callback)
    assert user.admin?
    assert_not user.worker?
    assert_not user.employer?
  end

  # Profile method
  test "profile returns worker_profile for workers" do
    user = create(:user, :worker, :without_profile_callback)
    profile = create(:worker_profile, user: user)
    assert_equal profile, user.profile
  end

  test "profile returns employer_profile for employers" do
    user = create(:user, :employer, :without_profile_callback)
    profile = create(:employer_profile, user: user)
    assert_equal profile, user.profile
  end

  test "profile returns nil for admin" do
    user = create(:user, :admin, :without_profile_callback)
    assert_nil user.profile
  end

  # has_profile?
  test "has_profile? returns true when profile exists" do
    user = create(:user, :worker, :without_profile_callback)
    create(:worker_profile, user: user)
    assert user.has_profile?
  end

  test "has_profile? returns false when profile does not exist" do
    user = create(:user, :worker, :without_profile_callback)
    assert_not user.has_profile?
  end

  # profile_completed?
  test "profile_completed? returns true when onboarding is complete" do
    user = create(:user, :worker, :without_profile_callback)
    create(:worker_profile, :onboarded, user: user)
    assert user.profile_completed?
  end

  test "profile_completed? returns false when onboarding is incomplete" do
    user = create(:user, :worker, :without_profile_callback)
    create(:worker_profile, user: user, onboarding_completed: false)
    assert_not user.profile_completed?
  end

  test "profile_completed? returns false when no profile exists" do
    user = create(:user, :worker, :without_profile_callback)
    assert_not user.profile_completed?
  end

  # JWT
  test "jwt_payload includes required fields" do
    user = create(:user, :worker, :without_profile_callback)
    payload = user.jwt_payload

    assert_equal user.id, payload["sub"]
    assert_equal user.jti, payload["jti"]
    assert_equal "worker", payload["role"]
  end

  test "jwt_payload includes correct role for employer" do
    user = create(:user, :employer, :without_profile_callback)
    payload = user.jwt_payload

    assert_equal "employer", payload["role"]
  end

  # Automatic profile creation callback
  test "creates employer profile when employer user is created" do
    # This tests the actual callback without the skip trait
    user = User.create!(
      email: "newemployer@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :employer
    )

    assert user.employer_profile.present?
    assert user.employer_profile.company.present?
  end
end
