# frozen_string_literal: true

class RecruitingAlgorithmService
  # Scoring weights (110 points max)
  DISTANCE_MAX_POINTS = 30
  RELIABILITY_MAX_POINTS = 25
  JOB_TYPE_MAX_POINTS = 20
  RATING_MAX_POINTS = 15
  RESPONSE_TIME_MAX_POINTS = 10
  EXPERIENCE_MAX_POINTS = 10

  # Distance scoring tiers (in miles)
  DISTANCE_TIERS = {
    (0..5) => 30,
    (5..10) => 25,
    (10..15) => 20,
    (15..20) => 15,
    (20..25) => 10
  }.freeze
  MAX_DISTANCE_MILES = 25

  # Response time scoring tiers (in minutes)
  RESPONSE_TIME_TIERS = {
    (0..5) => 10,
    (5..15) => 8,
    (15..30) => 5
  }.freeze

  attr_reader :shift

  def initialize(shift)
    @shift = shift
  end

  # Returns all eligible workers scored and ranked by score descending
  def ranked_eligible_workers
    eligible_workers.map { |worker| score_worker(worker) }
                    .sort_by { |result| -result[:score] }
  end

  # Returns the next best worker who hasn't been offered this shift
  def next_best_worker
    already_offered_ids = shift.shift_assignments.pluck(:worker_profile_id)
    ranked = ranked_eligible_workers.reject { |r| already_offered_ids.include?(r[:worker].id) }
    ranked.first
  end

  # Get all eligible workers for this shift
  def eligible_workers
    base_query
      .with_job_type_preference(shift.job_type)
      .with_coordinates
      .not_blocked_by_company(shift.company)
      .not_already_offered(shift)
      .select { |worker| within_max_distance?(worker) }
  end

  # Score a single worker for this shift
  def score_worker(worker)
    distance = calculate_distance(worker)
    breakdown = calculate_score_breakdown(worker, distance)
    total_score = breakdown.values.sum.round(2)

    {
      worker: worker,
      score: total_score,
      distance_miles: distance.round(2),
      score_breakdown: breakdown
    }
  end

  private

  def base_query
    WorkerProfile.active
                 .onboarded
                 .available_at(shift.start_datetime)
                 .includes(:worker_preferred_job_types, shift_assignments: :shift)
  end

  def calculate_score_breakdown(worker, distance)
    {
      distance: score_distance(distance),
      reliability: score_reliability(worker),
      job_type: score_job_type(worker),
      rating: score_rating(worker),
      response_time: score_response_time(worker),
      experience: score_experience(worker)
    }
  end

  def calculate_distance(worker)
    return Float::INFINITY unless worker.latitude && worker.longitude
    return Float::INFINITY unless shift.work_location.latitude && shift.work_location.longitude

    haversine_distance(
      worker.latitude, worker.longitude,
      shift.work_location.latitude, shift.work_location.longitude
    )
  end

  def within_max_distance?(worker)
    calculate_distance(worker) <= MAX_DISTANCE_MILES
  end

  # Haversine formula for distance between two coordinates (returns miles)
  def haversine_distance(lat1, lon1, lat2, lon2)
    rad_per_deg = Math::PI / 180
    earth_radius_miles = 3959.0

    dlat = (lat2 - lat1) * rad_per_deg
    dlon = (lon2 - lon1) * rad_per_deg

    a = Math.sin(dlat / 2)**2 +
        Math.cos(lat1 * rad_per_deg) * Math.cos(lat2 * rad_per_deg) *
        Math.sin(dlon / 2)**2

    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    earth_radius_miles * c
  end

  # Distance scoring: 30 points max, excluded at 25+ miles
  def score_distance(distance)
    return 0 if distance > MAX_DISTANCE_MILES

    DISTANCE_TIERS.each do |range, points|
      return points if range.cover?(distance)
    end

    0
  end

  # Reliability scoring: 25 points max, scaled from 0-100 reliability_score
  def score_reliability(worker)
    return 0 unless worker.reliability_score

    (worker.reliability_score / 100.0 * RELIABILITY_MAX_POINTS).round(2)
  end

  # Job type scoring: exact match = 20, completed similar = 10, no history = 5
  def score_job_type(worker)
    has_preference = worker.worker_preferred_job_types.any? { |preference| preference.job_type == shift.job_type }
    completed_this_type = worker.shift_assignments.any? do |assignment|
      assignment.completed? && assignment.shift&.job_type == shift.job_type
    end

    if has_preference && completed_this_type
      JOB_TYPE_MAX_POINTS
    elsif completed_this_type
      10
    elsif has_preference
      10
    else
      5
    end
  end

  # Rating scoring: 15 points max, scaled from 1-5 rating (new workers get 10)
  def score_rating(worker)
    return 10 unless worker.average_rating

    # Scale 1-5 rating to 0-15 points
    ((worker.average_rating - 1) / 4.0 * RATING_MAX_POINTS).round(2)
  end

  # Response time scoring: <5min=10, 5-15=8, 15-30=5, >30=2
  def score_response_time(worker)
    response_time = worker.average_response_time_minutes
    return 5 unless response_time # Default for new workers

    RESPONSE_TIME_TIERS.each do |range, points|
      return points if range.cover?(response_time)
    end

    2 # >30 minutes
  end

  # Experience scoring: 0.5 points per completed shift, capped at 10
  def score_experience(worker)
    [worker.total_shifts_completed * 0.5, EXPERIENCE_MAX_POINTS].min.round(2)
  end
end

