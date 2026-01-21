# frozen_string_literal: true

class Payment < ApplicationRecord
  # Associations
  belongs_to :shift_assignment
  belongs_to :worker_profile
  belongs_to :company

  # Enums
  enum :status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3,
    refunded: 4,
    disputed: 5
  }
  enum :payment_method, { direct_deposit: 0, check: 1, stripe: 2 }

  # Validations
  validates :shift_assignment_id, uniqueness: true
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :tax_year, numericality: { only_integer: true, greater_than: 2000 }, allow_nil: true

  # Scopes
  scope :pending_payments, -> { where(status: :pending) }
  scope :processing_payments, -> { where(status: :processing) }
  scope :completed_payments, -> { where(status: :completed) }
  scope :failed_payments, -> { where(status: :failed) }
  scope :disputed_payments, -> { where(status: :disputed) }
  scope :for_worker, ->(worker_id) { where(worker_profile_id: worker_id) }
  scope :for_company, ->(company_id) { where(company_id: company_id) }
  scope :for_tax_year, ->(year) { where(tax_year: year) }
  scope :for_1099, ->(worker_id, year) { where(worker_profile_id: worker_id, tax_year: year, status: :completed) }

  # Callbacks
  before_validation :set_tax_year_default
  before_validation :snapshot_shift_data

  # Instance methods - Payment processing
  def amount
    amount_cents / 100.0
  end

  def formatted_amount
    "$#{amount.round(2)}"
  end

  def process!
    return false unless pending?

    update!(
      status: :processing,
      processed_at: Time.current
    )

    # Here you would integrate with payment provider (Stripe, ACH, etc.)
    # For now, we'll simulate successful processing
    complete!
  end

  def complete!
    return false unless processing?

    update!(
      status: :completed,
      processed_at: Time.current || processed_at
    )
  end

  def fail!(reason)
    return false unless processing?

    update!(
      status: :failed,
      failed_at: Time.current,
      failure_reason: reason
    )
  end

  def refund!(reason = nil)
    return false unless completed?

    update!(
      status: :refunded,
      refunded_at: Time.current,
      refund_reason: reason
    )
  end

  def dispute!(reason)
    return false unless completed?

    update!(
      status: :disputed,
      disputed_at: Time.current,
      dispute_reason: reason
    )
  end

  def resolve_dispute!(resolution)
    return false unless disputed?

    update!(
      status: :completed,
      dispute_resolved_at: Time.current,
      dispute_resolution: resolution
    )
  end

  # Query methods
  def disputable?
    completed? && disputed_at.nil? && processed_at && (Time.current - processed_at) <= 7.days
  end

  def can_retry?
    failed?
  end

  # 1099 reporting
  def mark_included_in_1099!
    return false unless completed?

    update!(included_in_1099: true)
  end

  def year_to_date_total
    Payment
      .where(worker_profile: worker_profile, tax_year: tax_year, status: :completed)
      .sum(:amount_cents) / 100.0
  end

  def should_generate_1099?
    # 1099 required if total payments >= $600 in a tax year
    year_to_date_total >= 600.0
  end

  # Display helpers
  def worker_name
    worker_profile.full_name
  end

  def company_name
    company.name
  end

  def shift_title
    shift_assignment.shift.title
  end

  def status_display
    status.titleize
  end

  def payment_method_display
    payment_method.titleize.gsub('_', ' ')
  end

  private

  def set_tax_year_default
    self.tax_year ||= Time.current.year
  end

  def snapshot_shift_data
    return unless shift_assignment

    self.pay_rate_cents ||= shift_assignment.shift.pay_rate_cents
    self.hours_worked ||= shift_assignment.actual_hours_worked
  end
end
