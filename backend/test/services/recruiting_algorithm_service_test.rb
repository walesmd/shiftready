# frozen_string_literal: true

require "test_helper"

class RecruitingAlgorithmServiceTest < ActiveSupport::TestCase
  setup do
    @company = create(:company)
    @work_location = create(:work_location, company: @company, latitude: 29.4241, longitude: -98.4936) # San Antonio
    @employer = create(:employer_profile, :onboarded, company: @company)
    @shift = create(:shift, :recruiting,
                    company: @company,
                    work_location: @work_location,
                    created_by_employer: @employer,
                    job_type: "warehouse",
                    start_datetime: 2.days.from_now.change(hour: 8),
                    end_datetime: 2.days.from_now.change(hour: 16))
  end

  # Helper to create a worker with full eligibility
  def create_eligible_worker(attributes = {})
    worker = create(:worker_profile, :onboarded, {
      latitude: 29.4341, # Close to work location
      longitude: -98.5036,
      reliability_score: 80.0,
      average_rating: 4.5,
      average_response_time_minutes: 10,
      total_shifts_completed: 10
    }.merge(attributes))

    # Add job type preference
    create(:worker_preferred_job_type, worker_profile: worker, job_type: "warehouse")

    # Add availability for the shift day
    day_of_week = @shift.start_datetime.wday
    create(:worker_availability,
           worker_profile: worker,
           day_of_week: day_of_week,
           start_time: "06:00",
           end_time: "18:00")

    worker
  end

  test "initializes with a shift" do
    service = RecruitingAlgorithmService.new(@shift)
    assert_equal @shift, service.shift
  end

  # Distance scoring tests
  test "scores 30 points for workers within 5 miles" do
    worker = create_eligible_worker(latitude: 29.4261, longitude: -98.4956) # ~0.5 miles
    service = RecruitingAlgorithmService.new(@shift)

    result = service.score_worker(worker)
    assert_equal 30, result[:score_breakdown][:distance]
  end

  test "scores 25 points for workers 5-10 miles away" do
    # Approximately 7 miles away
    worker = create_eligible_worker(latitude: 29.5241, longitude: -98.4936)
    service = RecruitingAlgorithmService.new(@shift)

    result = service.score_worker(worker)
    assert_equal 25, result[:score_breakdown][:distance]
  end

  test "scores 20 points for workers 10-15 miles away" do
    # Approximately 12 miles away
    worker = create_eligible_worker(latitude: 29.6241, longitude: -98.4936)
    service = RecruitingAlgorithmService.new(@shift)

    result = service.score_worker(worker)
    assert_equal 20, result[:score_breakdown][:distance]
  end

  test "excludes workers beyond 25 miles" do
    # Approximately 30 miles away
    worker = create_eligible_worker(latitude: 29.8741, longitude: -98.4936)
    service = RecruitingAlgorithmService.new(@shift)

    eligible = service.eligible_workers
    assert_not_includes eligible, worker
  end

  # Reliability scoring tests
  test "scores reliability from 0-25 based on reliability_score" do
    worker = create_eligible_worker(reliability_score: 100.0)
    service = RecruitingAlgorithmService.new(@shift)

    result = service.score_worker(worker)
    assert_equal 25, result[:score_breakdown][:reliability]
  end

  test "scores 0 for reliability when no reliability_score" do
    worker = create_eligible_worker(reliability_score: nil)
    service = RecruitingAlgorithmService.new(@shift)

    result = service.score_worker(worker)
    assert_equal 0, result[:score_breakdown][:reliability]
  end

  # Job type scoring tests
  test "scores 20 for job type with preference and completed history" do
    worker = create_eligible_worker
    # Create a completed shift of same type
    completed_shift = create(:shift, :completed, company: @company, work_location: @work_location, job_type: "warehouse")
    create(:shift_assignment, :completed, shift: completed_shift, worker_profile: worker)

    service = RecruitingAlgorithmService.new(@shift)
    result = service.score_worker(worker)
    assert_equal 20, result[:score_breakdown][:job_type]
  end

  test "scores 10 for job type with only preference" do
    worker = create_eligible_worker
    service = RecruitingAlgorithmService.new(@shift)

    result = service.score_worker(worker)
    assert_equal 10, result[:score_breakdown][:job_type]
  end

  # Rating scoring tests
  test "scores rating from 0-15 based on average_rating" do
    worker = create_eligible_worker(average_rating: 5.0)
    service = RecruitingAlgorithmService.new(@shift)

    result = service.score_worker(worker)
    assert_equal 15, result[:score_breakdown][:rating]
  end

  test "scores 10 for new workers without rating" do
    worker = create_eligible_worker(average_rating: nil)
    service = RecruitingAlgorithmService.new(@shift)

    result = service.score_worker(worker)
    assert_equal 10, result[:score_breakdown][:rating]
  end

  # Response time scoring tests
  test "scores 10 for response time under 5 minutes" do
    worker = create_eligible_worker(average_response_time_minutes: 3)
    service = RecruitingAlgorithmService.new(@shift)

    result = service.score_worker(worker)
    assert_equal 10, result[:score_breakdown][:response_time]
  end

  test "scores 8 for response time 5-15 minutes" do
    worker = create_eligible_worker(average_response_time_minutes: 10)
    service = RecruitingAlgorithmService.new(@shift)

    result = service.score_worker(worker)
    assert_equal 8, result[:score_breakdown][:response_time]
  end

  test "scores 5 for response time 15-30 minutes" do
    worker = create_eligible_worker(average_response_time_minutes: 20)
    service = RecruitingAlgorithmService.new(@shift)

    result = service.score_worker(worker)
    assert_equal 5, result[:score_breakdown][:response_time]
  end

  test "scores 2 for response time over 30 minutes" do
    worker = create_eligible_worker(average_response_time_minutes: 45)
    service = RecruitingAlgorithmService.new(@shift)

    result = service.score_worker(worker)
    assert_equal 2, result[:score_breakdown][:response_time]
  end

  # Experience scoring tests
  test "scores 0.5 per completed shift, capped at 10" do
    worker = create_eligible_worker(total_shifts_completed: 15)
    service = RecruitingAlgorithmService.new(@shift)

    result = service.score_worker(worker)
    assert_equal 7.5, result[:score_breakdown][:experience]
  end

  test "caps experience score at 10 points" do
    worker = create_eligible_worker(total_shifts_completed: 30)
    service = RecruitingAlgorithmService.new(@shift)

    result = service.score_worker(worker)
    assert_equal 10, result[:score_breakdown][:experience]
  end

  # Eligibility filtering tests
  test "excludes inactive workers" do
    worker = create_eligible_worker(is_active: false)
    service = RecruitingAlgorithmService.new(@shift)

    eligible = service.eligible_workers
    assert_not_includes eligible, worker
  end

  test "excludes workers not onboarded" do
    worker = create(:worker_profile,
                    latitude: 29.4341,
                    longitude: -98.5036,
                    onboarding_completed: false)
    create(:worker_preferred_job_type, worker_profile: worker, job_type: "warehouse")

    service = RecruitingAlgorithmService.new(@shift)
    eligible = service.eligible_workers
    assert_not_includes eligible, worker
  end

  test "excludes workers without matching job type preference" do
    worker = create(:worker_profile, :onboarded,
                    latitude: 29.4341,
                    longitude: -98.5036)
    create(:worker_preferred_job_type, worker_profile: worker, job_type: "moving") # Different type

    day_of_week = @shift.start_datetime.wday
    create(:worker_availability, worker_profile: worker, day_of_week: day_of_week, start_time: "06:00", end_time: "18:00")

    service = RecruitingAlgorithmService.new(@shift)
    eligible = service.eligible_workers
    assert_not_includes eligible, worker
  end

  test "excludes workers without coordinates" do
    worker = create(:worker_profile, :onboarded, latitude: nil, longitude: nil)
    create(:worker_preferred_job_type, worker_profile: worker, job_type: "warehouse")

    service = RecruitingAlgorithmService.new(@shift)
    eligible = service.eligible_workers
    assert_not_includes eligible, worker
  end

  test "excludes workers blocked by company" do
    worker = create_eligible_worker
    create(:block_list, blocker: @company, blocked: worker)

    service = RecruitingAlgorithmService.new(@shift)
    eligible = service.eligible_workers
    assert_not_includes eligible, worker
  end

  test "excludes workers who blocked the company" do
    worker = create_eligible_worker
    create(:block_list, blocker: worker, blocked: @company)

    service = RecruitingAlgorithmService.new(@shift)
    eligible = service.eligible_workers
    assert_not_includes eligible, worker
  end

  test "excludes workers already offered this shift" do
    worker = create_eligible_worker
    create(:shift_assignment, :offered, shift: @shift, worker_profile: worker)

    service = RecruitingAlgorithmService.new(@shift)
    eligible = service.eligible_workers
    assert_not_includes eligible, worker
  end

  test "excludes workers not available at shift time" do
    worker = create(:worker_profile, :onboarded,
                    latitude: 29.4341,
                    longitude: -98.5036)
    create(:worker_preferred_job_type, worker_profile: worker, job_type: "warehouse")

    # Add availability for wrong day
    wrong_day = (@shift.start_datetime.wday + 1) % 7
    create(:worker_availability, worker_profile: worker, day_of_week: wrong_day, start_time: "06:00", end_time: "18:00")

    service = RecruitingAlgorithmService.new(@shift)
    eligible = service.eligible_workers
    assert_not_includes eligible, worker
  end

  # Ranking tests
  test "ranked_eligible_workers returns workers sorted by score descending" do
    worker1 = create_eligible_worker(reliability_score: 50.0)
    worker2 = create_eligible_worker(reliability_score: 100.0)

    service = RecruitingAlgorithmService.new(@shift)
    ranked = service.ranked_eligible_workers

    assert_equal worker2, ranked.first[:worker]
  end

  test "next_best_worker returns highest scored worker not yet offered" do
    worker1 = create_eligible_worker(reliability_score: 50.0)
    worker2 = create_eligible_worker(reliability_score: 100.0)
    create(:shift_assignment, :offered, shift: @shift, worker_profile: worker2)

    service = RecruitingAlgorithmService.new(@shift)
    result = service.next_best_worker

    assert_equal worker1, result[:worker]
  end

  test "next_best_worker returns nil when no eligible workers remain" do
    worker = create_eligible_worker
    create(:shift_assignment, :offered, shift: @shift, worker_profile: worker)

    service = RecruitingAlgorithmService.new(@shift)
    result = service.next_best_worker

    assert_nil result
  end

  # Score breakdown structure
  test "score_worker returns complete breakdown" do
    worker = create_eligible_worker
    service = RecruitingAlgorithmService.new(@shift)

    result = service.score_worker(worker)

    assert result[:worker].present?
    assert result[:score].is_a?(Numeric)
    assert result[:distance_miles].is_a?(Numeric)
    assert result[:score_breakdown].key?(:distance)
    assert result[:score_breakdown].key?(:reliability)
    assert result[:score_breakdown].key?(:job_type)
    assert result[:score_breakdown].key?(:rating)
    assert result[:score_breakdown].key?(:response_time)
    assert result[:score_breakdown].key?(:experience)
  end

  # Total score validation
  test "max score is 110 points" do
    # Create a perfect worker
    worker = create_eligible_worker(
      latitude: 29.4251,          # Very close
      longitude: -98.4946,
      reliability_score: 100.0,   # Max reliability
      average_rating: 5.0,        # Max rating
      average_response_time_minutes: 3, # Best response time
      total_shifts_completed: 25  # Max experience
    )

    # Add completed shift history for job type
    completed_shift = create(:shift, :completed, company: @company, work_location: @work_location, job_type: "warehouse")
    create(:shift_assignment, :completed, shift: completed_shift, worker_profile: worker)

    service = RecruitingAlgorithmService.new(@shift)
    result = service.score_worker(worker)

    # Max = 30 (distance) + 25 (reliability) + 20 (job_type) + 15 (rating) + 10 (response) + 10 (experience) = 110
    assert result[:score] <= 110
  end
end
