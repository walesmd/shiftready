# frozen_string_literal: true

class WorkLocation < ApplicationRecord
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

  # Geocoding support (will need geocoder gem)
  # geocoded_by :full_address
  # after_validation :geocode, if: ->(obj) { obj.address_line_1_changed? || obj.city_changed? || obj.state_changed? || obj.zip_code_changed? }

  def full_address
    [address_line_1, address_line_2, city, state, zip_code].compact.join(', ')
  end

  def display_name
    "#{name} - #{city}, #{state}"
  end
end
