# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "timecop"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Include FactoryBot methods
    include FactoryBot::Syntax::Methods

    # Add more helper methods to be used by all tests here...

    # Helper to sign in a user for integration tests
    def sign_in_user(user)
      post api_v1_user_session_path, params: {
        user: { email: user.email, password: "password123" }
      }
      response.parsed_body["token"]
    end

    # Helper for authenticated requests
    def auth_headers(user)
      token = generate_jwt_token(user)
      { "Authorization" => "Bearer #{token}" }
    end

    private

    def generate_jwt_token(user)
      # Ensure user has a jti set
      user.update(jti: SecureRandom.uuid) if user.jti.blank?
      Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
    end
  end
end

# Configure Shoulda Matchers
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :minitest
    with.library :rails
  end
end
