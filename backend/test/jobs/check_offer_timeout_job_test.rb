# frozen_string_literal: true

require "test_helper"

class CheckOfferTimeoutJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @company = create(:company)
    @work_location = create(:work_location, company: @company)
    @employer = create(:employer_profile, :onboarded, company: @company)
    @shift = create(:shift, :recruiting,
                    company: @company,
                    work_location: @work_location,
                    created_by_employer: @employer,
                    start_datetime: 2.days.from_now,
                    end_datetime: 2.days.from_now + 8.hours)
    @worker = create(:worker_profile, :onboarded)
  end

  test "marks assignment as no_response when still offered" do
    assignment = create(:shift_assignment, :offered,
                        shift: @shift,
                        worker_profile: @worker,
                        sms_sent_at: 15.minutes.ago)

    CheckOfferTimeoutJob.perform_now(assignment.id)

    assert assignment.reload.no_response?
  end

  test "logs offer_timeout" do
    assignment = create(:shift_assignment, :offered,
                        shift: @shift,
                        worker_profile: @worker,
                        sms_sent_at: 15.minutes.ago)

    CheckOfferTimeoutJob.perform_now(assignment.id)

    log = RecruitingActivityLog.find_by(shift: @shift, action: "offer_timeout")
    assert log.present?
    assert_equal assignment.id, log.shift_assignment_id
  end

  test "queues ProcessShiftRecruitingJob after timeout" do
    assignment = create(:shift_assignment, :offered,
                        shift: @shift,
                        worker_profile: @worker,
                        sms_sent_at: 15.minutes.ago)

    assert_enqueued_with(job: ProcessShiftRecruitingJob, args: [@shift.id]) do
      CheckOfferTimeoutJob.perform_now(assignment.id)
    end
  end

  test "does nothing when assignment not found" do
    assert_nothing_raised do
      CheckOfferTimeoutJob.perform_now(999999)
    end
  end

  test "does nothing when assignment already accepted" do
    assignment = create(:shift_assignment, :accepted,
                        shift: @shift,
                        worker_profile: @worker)

    CheckOfferTimeoutJob.perform_now(assignment.id)

    assert assignment.reload.accepted?
  end

  test "does nothing when assignment already declined" do
    assignment = create(:shift_assignment, :declined,
                        shift: @shift,
                        worker_profile: @worker)

    CheckOfferTimeoutJob.perform_now(assignment.id)

    assert assignment.reload.declined?
  end

  test "does nothing when assignment already no_response" do
    assignment = create(:shift_assignment,
                        shift: @shift,
                        worker_profile: @worker,
                        status: :no_response)

    # Should not raise or create duplicate logs
    CheckOfferTimeoutJob.perform_now(assignment.id)

    assert_equal 0, RecruitingActivityLog.where(shift: @shift, action: "offer_timeout").count
  end
end
