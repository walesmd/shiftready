# frozen_string_literal: true

class Company < ApplicationRecord
  include Geocodable
  include PhoneNormalizable

  # Configure geocoding for billing address fields
  geocodable prefix: 'billing_'

  # Configure phone normalization for billing phone
  normalize_phone_fields :billing_phone

  # Callbacks
  after_save :update_active_status, if: :saved_change_to_billing_or_work_locations?
  after_commit :update_employer_onboarding_status

  # Associations
  belongs_to :owner_employer_profile, class_name: 'EmployerProfile', optional: true, inverse_of: :owned_company
  has_many :employer_profiles, dependent: :restrict_with_error
  has_many :work_locations, dependent: :destroy
  has_many :shifts, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :billing_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :billing_zip_code, format: { with: /\A\d{5}(-\d{4})?\z/, message: 'must be a valid ZIP code' }, allow_blank: true

  # Note: tax_id and payment_terms are not currently used in the application.
  # They are reserved for future invoicing and billing features.

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :by_industry, ->(industry) { where(industry: industry) }

  def full_billing_address
    [
      billing_address_line_1,
      billing_address_line_2,
      billing_city,
      billing_state,
      billing_zip_code
    ].compact.join(', ')
  end

  def billing_phone_display
    PhoneNormalizationService.format_display(billing_phone)
  end

  def can_be_deleted?
    employer_profiles.empty? && shifts.empty?
  end

  # Onboarding status methods
  def billing_info_complete?
    billing_address_line_1.present? &&
      billing_city.present? &&
      billing_state.present? &&
      billing_zip_code.present? &&
      billing_email.present? &&
      billing_phone.present?
  end

  def has_work_locations?
    work_locations.exists?
  end

  def onboarding_complete?
    billing_info_complete? && has_work_locations?
  end

  def onboarding_status
    {
      billing_info_complete: billing_info_complete?,
      has_work_locations: has_work_locations?,
      is_complete: onboarding_complete?
    }
  end

  private

  def saved_change_to_billing_or_work_locations?
    saved_change_to_billing_address_line_1? ||
      saved_change_to_billing_city? ||
      saved_change_to_billing_state? ||
      saved_change_to_billing_zip_code? ||
      saved_change_to_billing_email? ||
      saved_change_to_billing_phone?
  end

  def update_active_status
    new_status = onboarding_complete?
    update_column(:is_active, new_status) if is_active != new_status
  end

  def update_employer_onboarding_status
    return unless onboarding_complete?

    employer_profiles.where(onboarding_completed: false).find_each do |profile|
      profile.update_column(:onboarding_completed, true)
    end
  end
end
