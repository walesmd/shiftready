# frozen_string_literal: true

module Api
  module V1
    class WorkerProfilesController < BaseController
      before_action :ensure_admin, only: [:index]
      before_action :ensure_worker_role, only: [:create, :update]
      before_action :set_worker_profile, only: [:show, :update]

      # GET /api/v1/workers
      def index
        workers = WorkerProfile.includes(:user, shift_assignments: { shift: :company })
        workers = apply_status_filter(workers)

        total_count = workers.count
        page = params[:page].to_i
        page = 1 if page < 1
        per_page = params[:per_page].to_i
        per_page = 12 if per_page < 1
        per_page = 200 if per_page > 200

        workers = workers
                  .order(Arel.sql(status_rank_sql))
                  .order(:last_name, :first_name)
                  .offset((page - 1) * per_page)
                  .limit(per_page)

        render json: {
          workers: workers.map { |profile| worker_summary(profile) },
          meta: {
            total: total_count,
            page: page,
            per_page: per_page,
            total_pages: (total_count / per_page.to_f).ceil
          }
        }
      end

      # POST /api/v1/workers
      def create
        if current_user.worker_profile.present?
          return render_error('Worker profile already exists', :conflict)
        end

        worker_profile = current_user.build_worker_profile(worker_profile_params)

        WorkerProfile.transaction do
          worker_profile.save!
          sync_preferred_job_types!(worker_profile)
          sync_availabilities!(worker_profile)
        end

        render json: worker_profile_response(worker_profile), status: :created
      rescue ActiveRecord::RecordInvalid => error
        render_errors(error.record.errors.full_messages)
      end

      # GET /api/v1/workers/me
      def show
        if @worker_profile
          render json: worker_profile_response(@worker_profile)
        else
          render_error('Worker profile not found', :not_found)
        end
      end

      # PATCH /api/v1/workers/me
      def update
        unless @worker_profile
          return render_error('Worker profile not found', :not_found)
        end

        WorkerProfile.transaction do
          @worker_profile.update!(worker_profile_params)
          sync_preferred_job_types!(@worker_profile) if preferred_job_types_provided?
          sync_availabilities!(@worker_profile) if availabilities_provided?
        end

        render json: worker_profile_response(@worker_profile)
      rescue ActiveRecord::RecordInvalid => error
        render_errors(error.record.errors.full_messages)
      end

      private

      def ensure_worker_role
        unless current_user.worker?
          render_error('Only workers can access this endpoint', :forbidden)
        end
      end

      def ensure_admin
        render_error('Only admins can access this endpoint', :forbidden) unless current_user.admin?
      end

      def set_worker_profile
        @worker_profile = current_user.worker_profile
      end

      def worker_profile_params
        params.require(:worker_profile).permit(
          :first_name,
          :last_name,
          :phone,
          :address_line_1,
          :address_line_2,
          :city,
          :state,
          :zip_code,
          :latitude,
          :longitude,
          :over_18_confirmed,
          :terms_accepted_at,
          :sms_consent_given_at,
          :ssn_encrypted,
          :preferred_payment_method,
          :bank_account_last_4
        )
      end

      def sync_preferred_job_types!(profile)
        preferred_job_types = preferred_job_types_params
        return if preferred_job_types.blank?

        profile.worker_preferred_job_types.destroy_all
        preferred_job_types.uniq.each do |job_type|
          profile.worker_preferred_job_types.create!(job_type: job_type)
        end
      end

      def sync_availabilities!(profile)
        availabilities = availabilities_params
        return if availabilities.blank?

        normalized = availabilities.map { |availability| normalize_availability(availability) }
        deduped = normalized.uniq
        validate_availability_overlaps!(profile, deduped)

        profile.worker_availabilities.destroy_all
        deduped.each do |availability|
          profile.worker_availabilities.create!(
            day_of_week: availability[:day_of_week],
            start_time: availability[:start_time],
            end_time: availability[:end_time]
          )
        end
      end

      def preferred_job_types_params
        params.require(:worker_profile).permit(preferred_job_types: [])[:preferred_job_types]
      rescue ActionController::ParameterMissing
        nil
      end

      def availabilities_params
        params.require(:worker_profile).permit(
          availabilities: [:day_of_week, :start_time, :end_time]
        )[:availabilities]
      rescue ActionController::ParameterMissing
        nil
      end

      def normalize_availability(availability)
        {
          day_of_week: availability[:day_of_week] || availability['day_of_week'],
          start_time: cast_time(availability[:start_time] || availability['start_time']),
          end_time: cast_time(availability[:end_time] || availability['end_time'])
        }
      end

      def cast_time(value)
        return value if value.is_a?(Time)
        return nil if value.blank?

        if Time.zone
          Time.zone.parse(value.to_s)
        else
          Time.parse(value.to_s)
        end
      rescue ArgumentError, TypeError
        nil
      end

      def validate_availability_overlaps!(profile, availabilities)
        errors = []

        availabilities.group_by { |availability| availability[:day_of_week] }.each do |day, entries|
          next if day.blank?

          sorted = entries.sort_by { |availability| availability[:start_time] || Time.at(0) }
          previous = nil

          sorted.each do |current|
            if previous && current[:start_time].present? && previous[:end_time].present?
              if current[:start_time] < previous[:end_time]
                errors << overlap_error_message(day, previous, current)
              end
            end

            previous = current if current[:end_time].present?
          end
        end

        return if errors.empty?

        errors.each { |message| profile.errors.add(:base, message) }
        raise ActiveRecord::RecordInvalid, profile
      end

      def overlap_error_message(day, first, second)
        day_name = WorkerAvailability::DAYS_OF_WEEK[day.to_i] || 'Selected day'
        "#{day_name} availability #{format_time_range(first)} overlaps with #{format_time_range(second)}"
      end

      def format_time_range(availability)
        start_time = availability[:start_time]&.strftime('%I:%M %p') || 'start time'
        end_time = availability[:end_time]&.strftime('%I:%M %p') || 'end time'
        "#{start_time}-#{end_time}"
      end

      def preferred_job_types_provided?
        params.dig(:worker_profile, :preferred_job_types).present?
      end

      def availabilities_provided?
        params.dig(:worker_profile, :availabilities).present?
      end

      def worker_profile_response(profile)
        {
          id: profile.id,
          user_id: profile.user_id,
          first_name: profile.first_name,
          last_name: profile.last_name,
          full_name: profile.full_name,
          phone: profile.phone,
          address: {
            line_1: profile.address_line_1,
            line_2: profile.address_line_2,
            city: profile.city,
            state: profile.state,
            zip_code: profile.zip_code,
            latitude: profile.latitude,
            longitude: profile.longitude
          },
          onboarding_completed: profile.onboarding_completed,
          over_18_confirmed: profile.over_18_confirmed,
          terms_accepted_at: profile.terms_accepted_at,
          sms_consent_given_at: profile.sms_consent_given_at,
          performance: {
            total_shifts_completed: profile.total_shifts_completed,
            total_shifts_assigned: profile.total_shifts_assigned,
            no_show_count: profile.no_show_count,
            average_rating: profile.average_rating,
            reliability_score: profile.reliability_score,
            attendance_rate: profile.attendance_rate,
            no_show_rate: profile.no_show_rate
          },
          payment_info: {
            preferred_payment_method: profile.preferred_payment_method,
            bank_account_last_4: profile.bank_account_last_4
          },
          is_active: profile.is_active,
          created_at: profile.created_at,
          updated_at: profile.updated_at
        }
      end

      def apply_status_filter(scope)
        case params[:status]
        when 'active'
          scope.where(is_active: true, onboarding_completed: true)
        when 'onboarding'
          scope.where(onboarding_completed: false)
        when 'inactive'
          scope.where(is_active: false)
        else
          scope
        end
      end

      def status_rank_sql
        <<~SQL.squish
          CASE
            WHEN worker_profiles.is_active = TRUE AND worker_profiles.onboarding_completed = TRUE THEN 0
            WHEN worker_profiles.is_active = FALSE THEN 1
            ELSE 2
          END
        SQL
      end

      def worker_summary(profile)
        last_assignment = last_completed_assignment(profile)
        last_shift = last_assignment ? last_shift_payload(last_assignment) : nil

        {
          id: profile.id,
          user_id: profile.user_id,
          first_name: profile.first_name,
          last_name: profile.last_name,
          full_name: profile.full_name,
          phone: profile.phone,
          onboarding_completed: profile.onboarding_completed,
          is_active: profile.is_active,
          status: worker_status(profile),
          total_shifts_completed: profile.total_shifts_completed,
          last_shift: last_shift
        }
      end

      def worker_status(profile)
        return 'active' if profile.is_active && profile.onboarding_completed
        return 'onboarding' unless profile.onboarding_completed

        'inactive'
      end

      def last_completed_assignment(profile)
        completed = profile.shift_assignments.select(&:completed?)
        return nil if completed.empty?

        completed.max_by do |assignment|
          assignment.timesheet_approved_at ||
            assignment.checked_out_at ||
            assignment.shift&.completed_at ||
            assignment.shift&.end_datetime ||
            assignment.assigned_at
        end
      end

      def last_shift_payload(assignment)
        shift = assignment.shift
        return nil unless shift

        {
          date: assignment.timesheet_approved_at || assignment.checked_out_at || shift.completed_at || shift.end_datetime,
          role: shift.title,
          job_type: shift.job_type,
          company_name: shift.company&.name
        }
      end
    end
  end
end
