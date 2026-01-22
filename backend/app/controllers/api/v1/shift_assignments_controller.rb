# frozen_string_literal: true

module Api
  module V1
    class ShiftAssignmentsController < BaseController
      before_action :set_shift_assignment, only: [:show, :accept, :decline, :check_in, :check_out, :cancel, :approve_timesheet]
      before_action :authorize_employer_assignment, only: [:approve_timesheet]
      before_action :authorize_worker, only: [:accept, :decline, :check_in, :check_out]
      before_action :authorize_assignment_worker, only: [:accept, :decline, :check_in, :check_out]
      before_action :authorize_cancellation, only: [:cancel]

      # GET /api/v1/shift_assignments
      def index
        assignments = ShiftAssignment.includes(:shift, :worker_profile)

        # Workers see only their own assignments
        if current_user.worker? && current_user.worker_profile.present?
          assignments = assignments.where(worker_profile_id: current_user.worker_profile.id)
        end

        # Employers see assignments for their company's shifts
        if current_user.employer? && current_user.employer_profile.present?
          company_id = current_user.employer_profile.company_id
          assignments = assignments.joins(:shift).where(shifts: { company_id: company_id })
        end

        # Apply filters
        assignments = assignments.where(status: params[:status]) if params[:status].present?
        assignments = assignments.where(shift_id: params[:shift_id]) if params[:shift_id].present?

        assignments = assignments.order(assigned_at: :desc).limit(100)

        render json: {
          shift_assignments: assignments.map { |assignment| assignment_response(assignment) },
          meta: {
            total: assignments.count
          }
        }
      end

      # GET /api/v1/shift_assignments/:id
      def show
        render json: assignment_response(@shift_assignment)
      end

      # POST /api/v1/shift_assignments/:id/accept
      def accept
        method = params[:method]&.to_sym || :app

        if @shift_assignment.accept!(method: method)
          render json: assignment_response(@shift_assignment)
        else
          render_error('Cannot accept this assignment', :unprocessable_entity)
        end
      end

      # POST /api/v1/shift_assignments/:id/decline
      def decline
        reason = params[:reason]
        method = params[:method]&.to_sym || :app

        if @shift_assignment.decline!(reason, method: method)
          render json: assignment_response(@shift_assignment)
        else
          render_error('Cannot decline this assignment', :unprocessable_entity)
        end
      end

      # POST /api/v1/shift_assignments/:id/check_in
      def check_in
        if @shift_assignment.check_in!
          render json: assignment_response(@shift_assignment)
        else
          render_error('Cannot check in to this shift', :unprocessable_entity)
        end
      end

      # POST /api/v1/shift_assignments/:id/check_out
      def check_out
        if @shift_assignment.check_out!
          render json: assignment_response(@shift_assignment)
        else
          render_error('Cannot check out of this shift', :unprocessable_entity)
        end
      end

      # POST /api/v1/shift_assignments/:id/cancel
      def cancel
        by = determine_canceller
        reason = params[:reason]

        if @shift_assignment.cancel!(by: by, reason: reason)
          render json: assignment_response(@shift_assignment)
        else
          render_error('Cannot cancel this assignment', :unprocessable_entity)
        end
      end

      # POST /api/v1/shift_assignments/:id/approve_timesheet (employer only)
      def approve_timesheet
        unless current_user.employer? && current_user.employer_profile.present?
          return render_error('Only employers can approve timesheets', :forbidden)
        end

        employer_profile = current_user.employer_profile

        unless employer_profile.can_approve_shift_timesheets?
          return render_error('You do not have permission to approve timesheets', :forbidden)
        end

        if @shift_assignment.approve_timesheet!(employer_profile)
          render json: assignment_response(@shift_assignment)
        else
          render_error('Cannot approve timesheet', :unprocessable_entity)
        end
      end

      private

      def set_shift_assignment
        @shift_assignment = ShiftAssignment.includes(:shift, :worker_profile).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error('Shift assignment not found', :not_found)
      end

      def authorize_worker
        unless current_user.worker? && current_user.worker_profile.present?
          render_error('Only workers can perform this action', :forbidden)
        end
      end

      def authorize_assignment_worker
        unless @shift_assignment.worker_profile_id == current_user.worker_profile&.id
          render_error('You do not have permission to modify this assignment', :forbidden)
        end
      end

      def authorize_employer_assignment
        return unless current_user.employer?

        employer_company_id = current_user.employer_profile&.company_id
        assignment_company_id = @shift_assignment.shift.company_id

        return if employer_company_id.present? && employer_company_id == assignment_company_id

        render_error('You do not have permission to modify this assignment', :forbidden)
      end

      def authorize_cancellation
        if current_user.worker?
          return if @shift_assignment.worker_profile_id == current_user.worker_profile&.id
        elsif current_user.employer?
          employer_company_id = current_user.employer_profile&.company_id
          assignment_company_id = @shift_assignment.shift.company_id
          return if employer_company_id.present? && employer_company_id == assignment_company_id
        elsif current_user.admin?
          return
        end

        render_error('You do not have permission to modify this assignment', :forbidden)
      end

      def determine_canceller
        if current_user.worker?
          :worker
        elsif current_user.employer?
          :employer
        elsif current_user.admin?
          :admin
        else
          :system
        end
      end

      def assignment_response(assignment)
        {
          id: assignment.id,
          shift: shift_summary(assignment.shift),
          worker: worker_summary(assignment.worker_profile),
          assignment_metadata: {
            assigned_at: assignment.assigned_at,
            assigned_by: assignment.assigned_by,
            algorithm_score: assignment.algorithm_score,
            distance_miles: assignment.distance_miles
          },
          recruiting_timeline: {
            sms_sent_at: assignment.sms_sent_at,
            sms_delivered_at: assignment.sms_delivered_at,
            response_received_at: assignment.response_received_at,
            response_method: assignment.response_method,
            response_value: assignment.response_value,
            response_time_minutes: assignment.response_time_minutes,
            decline_reason: assignment.decline_reason
          },
          status: assignment.status,
          status_timestamps: {
            accepted_at: assignment.accepted_at,
            confirmed_at: assignment.confirmed_at,
            cancelled_at: assignment.cancelled_at,
            cancellation_reason: assignment.cancellation_reason,
            cancelled_by: assignment.cancelled_by
          },
          timesheet: {
            checked_in_at: assignment.checked_in_at,
            checked_out_at: assignment.checked_out_at,
            actual_start_time: assignment.actual_start_time,
            actual_end_time: assignment.actual_end_time,
            actual_hours_worked: assignment.actual_hours_worked,
            timesheet_approved_at: assignment.timesheet_approved_at,
            calculated_pay_cents: assignment.calculated_pay_cents,
            formatted_pay: assignment.formatted_calculated_pay
          },
          performance: {
            worker_rating: assignment.worker_rating,
            employer_rating: assignment.employer_rating,
            worker_feedback: assignment.worker_feedback,
            employer_feedback: assignment.employer_feedback,
            no_show: assignment.no_show,
            completed_successfully: assignment.completed_successfully
          },
          created_at: assignment.created_at,
          updated_at: assignment.updated_at
        }
      end

      def shift_summary(shift)
        {
          id: shift.id,
          title: shift.title,
          job_type: shift.job_type,
          start_datetime: shift.start_datetime,
          end_datetime: shift.end_datetime,
          pay_rate_cents: shift.pay_rate_cents,
          formatted_pay_rate: shift.formatted_pay_rate,
          status: shift.status
        }
      end

      def worker_summary(worker)
        {
          id: worker.id,
          full_name: worker.full_name,
          phone: worker.phone,
          average_rating: worker.average_rating,
          reliability_score: worker.reliability_score
        }
      end
    end
  end
end
