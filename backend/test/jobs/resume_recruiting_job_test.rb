# frozen_string_literal: true

require "test_helper"

class ResumeRecruitingJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @company = create(:company)
    @work_location = create(:work_location, company: @company)
    @employer = create(:employer_profile, :onboarded, company: @company)
  end

  test "resumes recruiting for filled shift with available slots" do
    shift = create(:shift, :filled,
                   company: @company,
                   work_location: @work_location,
                   created_by_employer: @employer,
                   start_datetime: 3.days.from_now,
                   end_datetime: 3.days.from_now + 8.hours,
                   slots_total: 5,
                   slots_filled: 4) # One slot now available

    ResumeRecruitingJob.perform_now(shift.id)

    assert shift.reload.recruiting?
  end

  test "logs recruiting_resumed" do
    shift = create(:shift, :filled,
                   company: @company,
                   work_location: @work_location,
                   created_by_employer: @employer,
                   start_datetime: 3.days.from_now,
                   end_datetime: 3.days.from_now + 8.hours,
                   slots_total: 5,
                   slots_filled: 4)

    ResumeRecruitingJob.perform_now(shift.id)

    log = RecruitingActivityLog.find_by(shift: shift, action: "recruiting_resumed")
    assert log.present?
    assert log.details["resumed_at"].present?
  end

  test "enqueues ProcessShiftRecruitingJob" do
    shift = create(:shift, :filled,
                   company: @company,
                   work_location: @work_location,
                   created_by_employer: @employer,
                   start_datetime: 3.days.from_now,
                   end_datetime: 3.days.from_now + 8.hours,
                   slots_total: 5,
                   slots_filled: 4)

    assert_enqueued_with(job: ProcessShiftRecruitingJob, args: [shift.id]) do
      ResumeRecruitingJob.perform_now(shift.id)
    end
  end

  test "does nothing when shift not found" do
    assert_nothing_raised do
      ResumeRecruitingJob.perform_now(999999)
    end
  end

  test "does nothing when shift starts within 24 hours" do
    shift = create(:shift, :filled,
                   company: @company,
                   work_location: @work_location,
                   created_by_employer: @employer,
                   start_datetime: 12.hours.from_now,
                   end_datetime: 20.hours.from_now,
                   slots_total: 5,
                   slots_filled: 4)

    ResumeRecruitingJob.perform_now(shift.id)

    assert shift.reload.filled? # Status unchanged
  end

  test "does nothing when shift is fully filled" do
    shift = create(:shift, :filled,
                   company: @company,
                   work_location: @work_location,
                   created_by_employer: @employer,
                   start_datetime: 3.days.from_now,
                   end_datetime: 3.days.from_now + 8.hours,
                   slots_total: 5,
                   slots_filled: 5)

    ResumeRecruitingJob.perform_now(shift.id)

    assert shift.reload.filled? # Status unchanged
    assert_nil RecruitingActivityLog.find_by(shift: shift, action: "recruiting_resumed")
  end

  test "does nothing when shift is cancelled" do
    shift = create(:shift, :cancelled,
                   company: @company,
                   work_location: @work_location,
                   created_by_employer: @employer,
                   start_datetime: 3.days.from_now,
                   end_datetime: 3.days.from_now + 8.hours)

    ResumeRecruitingJob.perform_now(shift.id)

    assert shift.reload.cancelled?
  end

  test "does nothing when shift is completed" do
    shift = create(:shift, :completed,
                   company: @company,
                   work_location: @work_location,
                   created_by_employer: @employer)

    ResumeRecruitingJob.perform_now(shift.id)

    assert shift.reload.completed?
  end

  test "continues recruiting for already recruiting shift with available slots" do
    shift = create(:shift, :recruiting,
                   company: @company,
                   work_location: @work_location,
                   created_by_employer: @employer,
                   start_datetime: 3.days.from_now,
                   end_datetime: 3.days.from_now + 8.hours,
                   slots_total: 5,
                   slots_filled: 2)

    assert_enqueued_with(job: ProcessShiftRecruitingJob, args: [shift.id]) do
      ResumeRecruitingJob.perform_now(shift.id)
    end

    assert shift.reload.recruiting?
  end
end
