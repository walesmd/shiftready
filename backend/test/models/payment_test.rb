# frozen_string_literal: true

require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  # Associations
  test "belongs to shift_assignment" do
    payment = create(:payment)
    assert payment.shift_assignment.present?
  end

  test "belongs to worker_profile" do
    payment = create(:payment)
    assert payment.worker_profile.present?
  end

  test "belongs to company" do
    payment = create(:payment)
    assert payment.company.present?
  end

  # Validations
  test "requires unique shift_assignment" do
    assignment = create(:shift_assignment, :completed)
    create(:payment, shift_assignment: assignment)

    duplicate = build(:payment, shift_assignment: assignment)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:shift_assignment_id], "has already been taken"
  end

  test "requires amount_cents to be positive" do
    payment = build(:payment, amount_cents: 0)
    assert_not payment.valid?
    assert_includes payment.errors[:amount_cents], "must be greater than 0"
  end

  test "requires currency" do
    payment = build(:payment, currency: nil)
    assert_not payment.valid?
    assert_includes payment.errors[:currency], "can't be blank"
  end

  test "validates tax_year is integer greater than 2000" do
    payment = build(:payment, tax_year: 1999)
    assert_not payment.valid?
    assert_includes payment.errors[:tax_year], "must be greater than 2000"
  end

  test "allows nil tax_year" do
    payment = build(:payment, tax_year: nil)
    assert payment.valid?
  end

  # Enums
  test "status enum has correct values" do
    expected = {
      "pending" => 0,
      "processing" => 1,
      "completed" => 2,
      "failed" => 3,
      "refunded" => 4,
      "disputed" => 5
    }
    assert_equal expected, Payment.statuses
  end

  test "payment_method enum has correct values" do
    expected = { "direct_deposit" => 0, "check" => 1, "stripe" => 2 }
    assert_equal expected, Payment.payment_methods
  end

  # Scopes
  test "pending_payments scope returns pending payments" do
    pending = create(:payment, status: :pending)
    completed = create(:payment, :completed)

    assert_includes Payment.pending_payments, pending
    assert_not_includes Payment.pending_payments, completed
  end

  test "completed_payments scope returns completed payments" do
    pending = create(:payment, status: :pending)
    completed = create(:payment, :completed)

    assert_includes Payment.completed_payments, completed
    assert_not_includes Payment.completed_payments, pending
  end

  test "for_worker scope filters by worker" do
    worker1 = create(:worker_profile, :onboarded)
    worker2 = create(:worker_profile, :onboarded)
    assignment1 = create(:shift_assignment, :completed, worker_profile: worker1)
    assignment2 = create(:shift_assignment, :completed, worker_profile: worker2)
    payment1 = create(:payment, shift_assignment: assignment1, worker_profile: worker1)
    payment2 = create(:payment, shift_assignment: assignment2, worker_profile: worker2)

    assert_includes Payment.for_worker(worker1.id), payment1
    assert_not_includes Payment.for_worker(worker1.id), payment2
  end

  test "for_tax_year scope filters by year" do
    payment_2025 = create(:payment, tax_year: 2025)
    payment_2024 = create(:payment, tax_year: 2024)

    assert_includes Payment.for_tax_year(2025), payment_2025
    assert_not_includes Payment.for_tax_year(2025), payment_2024
  end

  test "for_1099 scope returns completed payments for worker and year" do
    worker = create(:worker_profile, :onboarded)
    assignment1 = create(:shift_assignment, :completed, worker_profile: worker)
    assignment2 = create(:shift_assignment, :completed, worker_profile: worker)
    completed = create(:payment, :completed, shift_assignment: assignment1, worker_profile: worker, tax_year: 2025)
    pending = create(:payment, shift_assignment: assignment2, worker_profile: worker, tax_year: 2025)

    scope = Payment.for_1099(worker.id, 2025)
    assert_includes scope, completed
    assert_not_includes scope, pending
  end

  # Instance methods
  test "amount returns amount in dollars" do
    payment = build(:payment, amount_cents: 12000)
    assert_equal 120.0, payment.amount
  end

  test "formatted_amount returns formatted string" do
    payment = build(:payment, amount_cents: 12050)
    assert_equal "$120.5", payment.formatted_amount
  end

  # ============================================================
  # STATUS TRANSITIONS
  # ============================================================

  # process!
  test "process! transitions pending to processing and completes" do
    payment = create(:payment, status: :pending)

    result = payment.process!

    assert result
    assert payment.completed?
    assert payment.processed_at.present?
  end

  test "process! returns false when not pending" do
    payment = create(:payment, :completed)

    result = payment.process!

    assert_not result
  end

  # complete!
  test "complete! transitions processing to completed" do
    payment = create(:payment, :processing)

    result = payment.complete!

    assert result
    assert payment.completed?
    assert payment.processed_at.present?
  end

  test "complete! returns false when not processing" do
    payment = create(:payment, status: :pending)

    result = payment.complete!

    assert_not result
  end

  # fail!
  test "fail! transitions processing to failed" do
    payment = create(:payment, :processing)

    result = payment.fail!("Insufficient funds")

    assert result
    assert payment.failed?
    assert payment.failed_at.present?
    assert_equal "Insufficient funds", payment.failure_reason
  end

  test "fail! returns false when not processing" do
    payment = create(:payment, status: :pending)

    result = payment.fail!("Error")

    assert_not result
  end

  # refund!
  test "refund! transitions completed to refunded" do
    payment = create(:payment, :completed)

    result = payment.refund!("Customer request")

    assert result
    assert payment.refunded?
    assert payment.refunded_at.present?
    assert_equal "Customer request", payment.refund_reason
  end

  test "refund! returns false when not completed" do
    payment = create(:payment, status: :pending)

    result = payment.refund!("Reason")

    assert_not result
  end

  # dispute!
  test "dispute! transitions completed to disputed" do
    payment = create(:payment, :completed)

    result = payment.dispute!("Hours disputed")

    assert result
    assert payment.disputed?
    assert payment.disputed_at.present?
    assert_equal "Hours disputed", payment.dispute_reason
  end

  test "dispute! returns false when not completed" do
    payment = create(:payment, status: :pending)

    result = payment.dispute!("Reason")

    assert_not result
  end

  # resolve_dispute!
  test "resolve_dispute! transitions disputed to completed" do
    payment = create(:payment, :disputed)

    result = payment.resolve_dispute!("Hours verified")

    assert result
    assert payment.completed?
    assert payment.dispute_resolved_at.present?
    assert_equal "Hours verified", payment.dispute_resolution
  end

  test "resolve_dispute! returns false when not disputed" do
    payment = create(:payment, :completed)

    result = payment.resolve_dispute!("Resolution")

    assert_not result
  end

  # ============================================================
  # QUERY METHODS
  # ============================================================

  test "disputable? returns true within 7 days of processing" do
    Timecop.freeze do
      payment = create(:payment, :completed, processed_at: 3.days.ago, disputed_at: nil)
      assert payment.disputable?
    end
  end

  test "disputable? returns false after 7 days" do
    Timecop.freeze do
      payment = create(:payment, :completed, processed_at: 8.days.ago, disputed_at: nil)
      assert_not payment.disputable?
    end
  end

  test "disputable? returns false when already disputed" do
    payment = create(:payment, :disputed)
    assert_not payment.disputable?
  end

  test "disputable? returns false when not completed" do
    payment = create(:payment, status: :pending)
    assert_not payment.disputable?
  end

  test "can_retry? returns true when failed" do
    payment = create(:payment, :failed)
    assert payment.can_retry?
  end

  test "can_retry? returns false when not failed" do
    payment = create(:payment, :completed)
    assert_not payment.can_retry?
  end

  # ============================================================
  # 1099 REPORTING
  # ============================================================

  test "mark_included_in_1099! marks completed payment" do
    payment = create(:payment, :completed, included_in_1099: false)

    result = payment.mark_included_in_1099!

    assert result
    assert payment.included_in_1099?
  end

  test "mark_included_in_1099! returns false for non-completed payment" do
    payment = create(:payment, status: :pending)

    result = payment.mark_included_in_1099!

    assert_not result
  end

  test "year_to_date_total calculates sum of completed payments" do
    worker = create(:worker_profile, :onboarded)
    year = Time.current.year

    # Create 3 completed payments for $100, $150, $200
    assignment1 = create(:shift_assignment, :completed, worker_profile: worker)
    assignment2 = create(:shift_assignment, :completed, worker_profile: worker)
    assignment3 = create(:shift_assignment, :completed, worker_profile: worker)
    assignment4 = create(:shift_assignment, :completed, worker_profile: worker)

    create(:payment, :completed, shift_assignment: assignment1, worker_profile: worker, amount_cents: 10000, tax_year: year)
    create(:payment, :completed, shift_assignment: assignment2, worker_profile: worker, amount_cents: 15000, tax_year: year)
    create(:payment, :completed, shift_assignment: assignment3, worker_profile: worker, amount_cents: 20000, tax_year: year)
    # Pending payment should not count
    create(:payment, shift_assignment: assignment4, worker_profile: worker, amount_cents: 50000, tax_year: year, status: :pending)

    payment = Payment.for_worker(worker.id).for_tax_year(year).completed_payments.first

    assert_equal 450.0, payment.year_to_date_total
  end

  test "should_generate_1099? returns true when YTD >= $600" do
    worker = create(:worker_profile, :onboarded)
    year = Time.current.year

    assignment = create(:shift_assignment, :completed, worker_profile: worker)
    payment = create(:payment, :completed, shift_assignment: assignment, worker_profile: worker, amount_cents: 60000, tax_year: year)

    assert payment.should_generate_1099?
  end

  test "should_generate_1099? returns false when YTD < $600" do
    worker = create(:worker_profile, :onboarded)
    year = Time.current.year

    assignment = create(:shift_assignment, :completed, worker_profile: worker)
    payment = create(:payment, :completed, shift_assignment: assignment, worker_profile: worker, amount_cents: 50000, tax_year: year)

    assert_not payment.should_generate_1099?
  end

  test "should_generate_1099? returns true when multiple payments total >= $600" do
    worker = create(:worker_profile, :onboarded)
    year = Time.current.year

    assignment1 = create(:shift_assignment, :completed, worker_profile: worker)
    assignment2 = create(:shift_assignment, :completed, worker_profile: worker)
    assignment3 = create(:shift_assignment, :completed, worker_profile: worker)

    create(:payment, :completed, shift_assignment: assignment1, worker_profile: worker, amount_cents: 20000, tax_year: year)
    create(:payment, :completed, shift_assignment: assignment2, worker_profile: worker, amount_cents: 20000, tax_year: year)
    payment = create(:payment, :completed, shift_assignment: assignment3, worker_profile: worker, amount_cents: 20000, tax_year: year)

    assert payment.should_generate_1099?
  end

  # ============================================================
  # CALLBACKS - Default values
  # ============================================================

  test "sets tax_year default to current year" do
    payment = build(:payment, tax_year: nil)
    payment.valid?

    assert_equal Time.current.year, payment.tax_year
  end

  test "snapshots shift data from assignment" do
    shift = create(:shift, pay_rate_cents: 2000)
    assignment = create(:shift_assignment, :completed, shift: shift, actual_hours_worked: 6.5)
    payment = build(:payment, shift_assignment: assignment, pay_rate_cents: nil, hours_worked: nil)
    payment.valid?

    assert_equal 2000, payment.pay_rate_cents
    assert_equal 6.5, payment.hours_worked
  end

  # ============================================================
  # DISPLAY HELPERS
  # ============================================================

  test "worker_name returns worker full name" do
    worker = create(:worker_profile, first_name: "Jane", last_name: "Smith")
    assignment = create(:shift_assignment, :completed, worker_profile: worker)
    payment = create(:payment, shift_assignment: assignment, worker_profile: worker)

    assert_equal "Jane Smith", payment.worker_name
  end

  test "company_name returns company name" do
    company = create(:company, name: "Acme Corp")
    assignment = create(:shift_assignment, :completed)
    payment = create(:payment, shift_assignment: assignment, company: company)

    assert_equal "Acme Corp", payment.company_name
  end

  test "shift_title returns shift title" do
    shift = create(:shift, title: "Warehouse Shift")
    assignment = create(:shift_assignment, :completed, shift: shift)
    payment = create(:payment, shift_assignment: assignment)

    assert_equal "Warehouse Shift", payment.shift_title
  end

  test "status_display returns titleized status" do
    payment = build(:payment, status: :processing)
    assert_equal "Processing", payment.status_display
  end

  test "payment_method_display returns formatted method" do
    payment = build(:payment, payment_method: :direct_deposit)
    assert_equal "Direct Deposit", payment.payment_method_display
  end
end
