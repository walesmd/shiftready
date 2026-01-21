# frozen_string_literal: true

class Company < ApplicationRecord
  # Associations
  has_many :employer_profiles, dependent: :restrict_with_error
  has_many :work_locations, dependent: :destroy
  has_many :shifts, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :billing_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :billing_zip_code, format: { with: /\A\d{5}(-\d{4})?\z/, message: 'must be a valid ZIP code' }, allow_blank: true

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

  def can_be_deleted?
    employer_profiles.empty? && shifts.empty?
  end
end
