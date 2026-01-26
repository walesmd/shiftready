# frozen_string_literal: true

class EmployerProfile < ApplicationRecord
  include PhoneNormalizable

  # Associations
  belongs_to :user
  belongs_to :company
  has_one :owned_company, class_name: 'Company', foreign_key: :owner_employer_profile_id, inverse_of: :owner_employer_profile
  has_many :shifts, foreign_key: :created_by_employer_id, dependent: :restrict_with_error, inverse_of: :created_by_employer
  has_many :messages, as: :messageable

  # Validations
  validates :first_name, :last_name, :phone, presence: true
  validates :phone, format: { with: /\A\+1\d{10}\z/, message: 'must be a valid phone number' }

  # Scopes
  scope :onboarded, -> { where(onboarding_completed: true) }
  scope :can_post, -> { where(can_post_shifts: true) }
  scope :can_approve, -> { where(can_approve_timesheets: true) }
  scope :billing_contacts, -> { where(is_billing_contact: true) }
  scope :for_company, ->(company_id) { where(company_id: company_id) }

  def full_name
    "#{first_name} #{last_name}"
  end

  def can_create_shifts?
    onboarding_completed? && can_post_shifts?
  end

  def can_approve_shift_timesheets?
    onboarding_completed? && can_approve_timesheets?
  end

  def phone_display
    PhoneNormalizationService.format_display(phone)
  end
end
