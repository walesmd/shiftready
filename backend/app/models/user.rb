# frozen_string_literal: true

class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  # User roles
  enum :role, { worker: 0, employer: 1, admin: 2 }

  # Associations
  has_one :worker_profile, dependent: :destroy
  has_one :employer_profile, dependent: :destroy

  # Validations
  validates :role, presence: true

  # Callbacks
  after_create :create_profile_for_role

  # Delegations for convenience
  delegate :full_name, to: :worker_profile, prefix: :worker, allow_nil: true
  delegate :full_name, to: :employer_profile, prefix: :employer, allow_nil: true

  # Generate a unique JTI for JWT tokens
  def jwt_payload
    {
      "sub" => id,
      "jti" => jti,
      "role" => role
    }
  end

  # Helper methods
  def profile
    case role
    when 'worker'
      worker_profile
    when 'employer'
      employer_profile
    else
      nil
    end
  end

  def has_profile?
    profile.present?
  end

  def profile_completed?
    profile&.onboarding_completed?
  end

  private

  def create_profile_for_role
    case role
    when 'employer'
      create_employer_profile_with_company
    when 'worker'
      create_worker_profile_placeholder
    end
  end

  def create_employer_profile_with_company
    # Get company and profile attributes from registration if provided
    company_attrs = instance_variable_get(:@company_attributes) || {}
    profile_attrs = instance_variable_get(:@employer_profile_attributes) || {}

    # Create company with provided data or placeholders
    company = Company.create!(
      name: company_attrs['name'] || "#{email.split('@').first}'s Company",
      industry: company_attrs['industry'],
      billing_address_line_1: company_attrs['billing_address_line_1'],
      billing_city: company_attrs['billing_city'],
      billing_state: company_attrs['billing_state'] || 'TX',
      billing_zip_code: company_attrs['billing_zip_code'],
      workers_needed_per_week: company_attrs['workers_needed_per_week'],
      typical_roles: company_attrs['typical_roles'],
      is_active: false # Set to inactive until onboarding is complete
    )

    # Create the employer profile with provided data or placeholders
    create_employer_profile!(
      company: company,
      first_name: profile_attrs['first_name'] || email.split('@').first.capitalize,
      last_name: profile_attrs['last_name'] || 'User',
      title: profile_attrs['title'],
      phone: profile_attrs['phone'] || '+11234567890',
      terms_accepted_at: profile_attrs['terms_accepted_at'],
      msa_accepted_at: profile_attrs['msa_accepted_at'],
      onboarding_completed: false
    )
  end

  def create_worker_profile_placeholder
    # Create minimal worker profile if needed
    # This can be implemented later when worker registration is built
  end
end
