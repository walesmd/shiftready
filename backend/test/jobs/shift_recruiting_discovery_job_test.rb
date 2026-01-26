# frozen_string_literal: true

require "test_helper"

class ShiftRecruitingDiscoveryJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @company = create(:company)
    @work_location = create(:work_location, company: @company)
    @employer = create(:employer_profile, :onboarded, company: @company)
  end

  test "discovers posted shifts starting within 7 days" do
    shift = create(:shift, :posted,
                   company: @company,
                   work_location: @work_location,
                   created_by_employer: @employer,
                   start_datetime: 3.days.from_now,
                   end_datetime: 3.days.from_now + 8.hours)

    ShiftRecruitingDiscoveryJob.perform_now

    assert shift.reload.recruiting?
    assert shift.recruiting_started_at.present?
  end

  test "does not discover draft shifts" do
    shift = create(:shift,
                   status: :draft,
                   company: @company,
                   work_location: @work_location,
                   created_by_employer: @employer,
                   start_datetime: 3.days.from_now,
                   end_datetime: 3.days.from_now + 8.hours)

    ShiftRecruitingDiscoveryJob.perform_now

    assert shift.reload.draft?
  end

  test "does not discover shifts more than 7 days away" do
    shift = create(:shift, :posted,
                   company: @company,
                   work_location: @work_location,
                   created_by_employer: @employer,
                   start_datetime: 10.days.from_now,
                   end_datetime: 10.days.from_now + 8.hours)

    ShiftRecruitingDiscoveryJob.perform_now

    assert shift.reload.posted?
  end

  test "does not discover past shifts" do
    shift = create(:shift, :posted,
                   company: @company,
                   work_location: @work_location,
                   created_by_employer: @employer,
                   start_datetime: 1.day.ago,
                   end_datetime: 1.day.ago + 8.hours)

    ShiftRecruitingDiscoveryJob.perform_now

    assert shift.reload.posted?
  end

  test "does not discover fully filled shifts" do
    shift = create(:shift, :posted,
                   company: @company,
                   work_location: @work_location,
                   created_by_employer: @employer,
                   start_datetime: 3.days.from_now,
                   end_datetime: 3.days.from_now + 8.hours,
                   slots_total: 5,
                   slots_filled: 5)

    ShiftRecruitingDiscoveryJob.perform_now

    assert shift.reload.posted?
  end

  test "logs recruiting_started for discovered shifts" do
    shift = create(:shift, :posted,
                   company: @company,
                   work_location: @work_location,
                   created_by_employer: @employer,
                   start_datetime: 3.days.from_now,
                   end_datetime: 3.days.from_now + 8.hours)

    ShiftRecruitingDiscoveryJob.perform_now

    log = RecruitingActivityLog.find_by(shift: shift, action: "recruiting_started")
    assert log.present?
    assert log.details["discovered_at"].present?
  end

  test "enqueues ProcessShiftRecruitingJob for discovered shifts" do
    shift = create(:shift, :posted,
                   company: @company,
                   work_location: @work_location,
                   created_by_employer: @employer,
                   start_datetime: 3.days.from_now,
                   end_datetime: 3.days.from_now + 8.hours)

    assert_enqueued_with(job: ProcessShiftRecruitingJob, args: [shift.id]) do
      ShiftRecruitingDiscoveryJob.perform_now
    end
  end

  test "discovers multiple shifts in single run" do
    shift1 = create(:shift, :posted,
                    company: @company,
                    work_location: @work_location,
                    created_by_employer: @employer,
                    start_datetime: 2.days.from_now,
                    end_datetime: 2.days.from_now + 8.hours)
    shift2 = create(:shift, :posted,
                    company: @company,
                    work_location: @work_location,
                    created_by_employer: @employer,
                    start_datetime: 4.days.from_now,
                    end_datetime: 4.days.from_now + 8.hours)

    ShiftRecruitingDiscoveryJob.perform_now

    assert shift1.reload.recruiting?
    assert shift2.reload.recruiting?
  end

  test "continues processing other shifts when one fails" do
    shift1 = create(:shift, :posted,
                    company: @company,
                    work_location: @work_location,
                    created_by_employer: @employer,
                    start_datetime: 2.days.from_now,
                    end_datetime: 2.days.from_now + 8.hours)
    shift2 = create(:shift, :posted,
                    company: @company,
                    work_location: @work_location,
                    created_by_employer: @employer,
                    start_datetime: 4.days.from_now,
                    end_datetime: 4.days.from_now + 8.hours)

    # Make shift1 fail by invalidating it mid-process
    Shift.where(id: shift1.id).update_all(status: :draft)

    ShiftRecruitingDiscoveryJob.perform_now

    # shift2 should still be processed
    assert shift2.reload.recruiting?
  end
end
