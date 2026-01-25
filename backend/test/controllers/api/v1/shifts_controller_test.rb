# frozen_string_literal: true

require "test_helper"

class Api::V1::ShiftsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @company = create(:company)
    @employer = create(:user, :employer)
    @employer_profile = @employer.employer_profile
    @employer_profile.update!(company: @company)
    @work_location = create(:work_location, company: @company)

    # Create shifts with different statuses
    @posted_shift = create(:shift,
      company: @company,
      work_location: @work_location,
      created_by_employer: @employer_profile,
      status: :posted,
      start_datetime: 2.hours.from_now,
      end_datetime: 10.hours.from_now
    )

    @recruiting_shift = create(:shift,
      company: @company,
      work_location: @work_location,
      created_by_employer: @employer_profile,
      status: :recruiting,
      start_datetime: 1.day.from_now,
      end_datetime: 1.day.from_now + 8.hours
    )

    @filled_shift = create(:shift,
      company: @company,
      work_location: @work_location,
      created_by_employer: @employer_profile,
      status: :filled,
      start_datetime: 2.days.from_now,
      end_datetime: 2.days.from_now + 8.hours
    )

    @draft_shift = create(:shift,
      company: @company,
      work_location: @work_location,
      created_by_employer: @employer_profile,
      status: :draft,
      start_datetime: 3.days.from_now,
      end_datetime: 3.days.from_now + 8.hours
    )

    # Create a shift for a different company
    @other_company = create(:company, name: "Other Company")
    @other_work_location = create(:work_location, company: @other_company)
    @other_employer = create(:user, :employer)
    @other_employer_profile = @other_employer.employer_profile
    @other_employer_profile.update!(company: @other_company)

    @other_shift = create(:shift,
      company: @other_company,
      work_location: @other_work_location,
      created_by_employer: @other_employer_profile,
      status: :posted,
      start_datetime: 1.day.from_now,
      end_datetime: 1.day.from_now + 8.hours
    )
  end

  # ============================================================
  # GET /api/v1/shifts - Status Filter
  # ============================================================

  test "filters shifts by single status" do
    get "/api/v1/shifts",
        params: { status: "posted" },
        headers: auth_headers(@employer)

    assert_response :ok
    json = JSON.parse(response.body)

    assert_equal 1, json["shifts"].length
    assert_equal "posted", json["shifts"][0]["status"]
  end

  test "filters shifts by comma-separated statuses" do
    get "/api/v1/shifts",
        params: { status: "posted,recruiting,filled" },
        headers: auth_headers(@employer)

    assert_response :ok
    json = JSON.parse(response.body)

    # Should return 3 shifts (posted, recruiting, filled) but not draft
    assert_equal 3, json["shifts"].length
    statuses = json["shifts"].map { |s| s["status"] }
    assert_includes statuses, "posted"
    assert_includes statuses, "recruiting"
    assert_includes statuses, "filled"
    refute_includes statuses, "draft"
  end

  test "filters shifts by comma-separated statuses with spaces" do
    get "/api/v1/shifts",
        params: { status: "posted, recruiting, filled, in_progress" },
        headers: auth_headers(@employer)

    assert_response :ok
    json = JSON.parse(response.body)

    # Should handle spaces in the comma-separated list
    assert_equal 3, json["shifts"].length
  end

  # ============================================================
  # GET /api/v1/shifts - Company Filtering for Employers
  # ============================================================

  test "employer sees only their company's shifts" do
    get "/api/v1/shifts",
        headers: auth_headers(@employer)

    assert_response :ok
    json = JSON.parse(response.body)

    # Should only see shifts from their own company, not @other_shift
    company_ids = json["shifts"].map { |s| s["company"]["id"] }.uniq
    assert_equal [@company.id], company_ids
  end

  test "employer with status filter sees only their company's shifts" do
    get "/api/v1/shifts",
        params: { status: "posted,recruiting,filled,in_progress" },
        headers: auth_headers(@employer)

    assert_response :ok
    json = JSON.parse(response.body)

    # Should see their company's posted, recruiting, and filled shifts
    assert_equal 3, json["shifts"].length
    company_ids = json["shifts"].map { |s| s["company"]["id"] }.uniq
    assert_equal [@company.id], company_ids
  end

  # ============================================================
  # GET /api/v1/shifts - Admin Access
  # ============================================================

  test "admin sees shifts from all companies" do
    admin = create(:user, :admin)

    get "/api/v1/shifts",
        params: { status: "posted" },
        headers: auth_headers(admin)

    assert_response :ok
    json = JSON.parse(response.body)

    # Should see posted shifts from both companies
    assert_equal 2, json["shifts"].length
    company_ids = json["shifts"].map { |s| s["company"]["id"] }.sort
    assert_equal [@company.id, @other_company.id].sort, company_ids
  end

  # ============================================================
  # GET /api/v1/shifts - Date Filtering
  # ============================================================

  test "filters shifts by date range" do
    today = Date.today
    start_of_day = today.beginning_of_day
    end_of_day = today.end_of_day

    get "/api/v1/shifts",
        params: {
          start_date: start_of_day.iso8601,
          end_date: end_of_day.iso8601
        },
        headers: auth_headers(@employer)

    assert_response :ok
    json = JSON.parse(response.body)

    # Should only see shifts starting today
    json["shifts"].each do |shift|
      shift_start = DateTime.parse(shift["schedule"]["start_datetime"])
      assert shift_start >= start_of_day
      assert shift_start <= end_of_day
    end
  end
end
