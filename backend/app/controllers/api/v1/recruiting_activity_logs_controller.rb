# frozen_string_literal: true

module Api
  module V1
    class RecruitingActivityLogsController < BaseController
      before_action :set_shift
      before_action :authorize_access

      # GET /api/v1/shifts/:shift_id/recruiting_activity_logs
      def index
        logs = @shift.recruiting_activity_logs.includes(:worker_profile, :shift_assignment)

        # Apply filters
        logs = logs.by_action(params[:action_type]) if params[:action_type].present?
        logs = logs.for_worker(params[:worker_id]) if params[:worker_id].present?

        # Order chronologically by default
        logs = logs.chronological

        # Pagination
        page = params[:page].to_i
        page = 1 if page < 1
        per_page = params[:per_page].to_i
        per_page = 50 if per_page < 1
        per_page = 100 if per_page > 100

        total_count = logs.count
        logs = logs.offset((page - 1) * per_page).limit(per_page)

        render json: {
          recruiting_activity_logs: logs.map { |log| log_response(log) },
          meta: {
            total: total_count,
            page: page,
            per_page: per_page,
            total_pages: (total_count / per_page.to_f).ceil,
            shift_id: @shift.id,
            shift_tracking_code: @shift.tracking_code
          }
        }
      end

      private

      def set_shift
        @shift = Shift.find(params[:shift_id])
      rescue ActiveRecord::RecordNotFound
        render_error('Shift not found', :not_found)
      end

      def authorize_access
        # Allow employers who own the shift's company or admins
        if current_user.employer?
          unless current_user.employer_profile&.company_id == @shift.company_id
            render_error('You do not have permission to view this data', :forbidden)
          end
        elsif !current_user.admin?
          render_error('You do not have permission to view this data', :forbidden)
        end
      end

      def log_response(log)
        response = {
          id: log.id,
          action: log.action,
          source: log.source,
          details: log.details,
          created_at: log.created_at
        }

        if log.worker_profile
          response[:worker] = {
            id: log.worker_profile.id,
            name: log.worker_profile.full_name
          }
        end

        if log.shift_assignment
          response[:shift_assignment] = {
            id: log.shift_assignment.id,
            status: log.shift_assignment.status,
            algorithm_score: log.shift_assignment.algorithm_score,
            distance_miles: log.shift_assignment.distance_miles
          }
        end

        response
      end
    end
  end
end
