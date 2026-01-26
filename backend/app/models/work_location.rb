# frozen_string_literal: true

class WorkLocation < ApplicationRecord
  include Geocodable

  # Callbacks
  after_commit :update_company_onboarding_status, on: %i[create update destroy]

  # Associations
  belongs_to :company
  has_many :shifts, dependent: :restrict_with_error

  # Validations
  validates :name, :address_line_1, :city, :state, :zip_code, presence: true
  validates :state, length: { is: 2 }
  validates :zip_code, format: { with: /\A\d{5}(-\d{4})?\z/, message: 'must be a valid ZIP code' }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :for_company, ->(company_id) { where(company_id: company_id) }

  def full_address
    [address_line_1, address_line_2, city, state, zip_code].compact.join(', ')
  end

  def display_name
    "#{name} - #{city}, #{state}"
  end

  private

  def update_company_onboarding_status
    return if company.nil? || company.destroyed?

    company.refresh_onboarding_status!
  end
end
