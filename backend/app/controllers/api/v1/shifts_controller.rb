# frozen_string_literal: true

module Api
  module V1
    class ShiftsController < BaseController
      before_action :set_shift, only: [:show, :update, :destroy, :start_recruiting, :cancel]
      before_action :authorize_employer, only: [:create, :update, :destroy, :start_recruiting, :cancel]
      before_action :authorize_shift_owner, only: [:update, :destroy, :cancel]

      # GET /api/v1/shifts
      def index
        shifts = Shift.includes(:company, :work_location, :created_by_employer)

        # Apply filters
        if params[:status].present?
          # Parse comma-separated status values into an array
          status_values = params[:status].to_s.split(',').map(&:strip)
          shifts = shifts.where(status: status_values)
        end
        shifts = shifts.where(job_type: params[:job_type]) if params[:job_type].present?
        shifts = shifts.where(company_id: params[:company_id]) if params[:company_id].present?
        shifts = shifts.where('start_datetime >= ?', params[:start_date]) if params[:start_date].present?
        shifts = shifts.where('start_datetime <= ?', params[:end_date]) if params[:end_date].present?

        # Workers see only posted/recruiting shifts
        if current_user.worker?
          shifts = shifts.where(status: [:posted, :recruiting])
        end

        # Employers see only their company's shifts
        if current_user.employer? && current_user.employer_profile.present?
          shifts = shifts.where(company_id: current_user.employer_profile.company_id)
        end

        total_count = shifts.count
        page = params[:page].to_i
        page = 1 if page < 1
        per_page = params[:per_page].to_i
        per_page = 100 if per_page < 1
        per_page = 200 if per_page > 200
        direction = params[:direction].to_s.downcase == 'desc' ? :desc : :asc

        shifts = shifts
                 .order(start_datetime: direction)
                 .offset((page - 1) * per_page)
                 .limit(per_page)

        render json: {
          shifts: shifts.map { |shift| shift_response(shift) },
          meta: {
            total: total_count,
            page: page,
            per_page: per_page,
            total_pages: (total_count / per_page.to_f).ceil
          }
        }
      end

      # GET /api/v1/shifts/:id
      def show
        render json: shift_response(@shift)
      end

      # POST /api/v1/shifts
      def create
        employer_profile = current_user.employer_profile

        unless employer_profile&.can_create_shifts?
          return render_error('You do not have permission to create shifts', :forbidden)
        end

        shift = employer_profile.shifts.build(shift_params)
        shift.company_id = employer_profile.company_id

        if shift.save
          render json: shift_response(shift), status: :created
        else
          render_errors(shift.errors.full_messages)
        end
      end

      # PATCH /api/v1/shifts/:id
      def update
        if @shift.update(shift_params)
          render json: shift_response(@shift)
        else
          render_errors(@shift.errors.full_messages)
        end
      end

      # DELETE /api/v1/shifts/:id
      def destroy
        if @shift.can_be_deleted?
          @shift.destroy
          head :no_content
        else
          render_error('Cannot delete shift with active assignments', :unprocessable_entity)
        end
      end

      # POST /api/v1/shifts/:id/start_recruiting
      def start_recruiting
        if @shift.start_recruiting!
          render json: shift_response(@shift)
        else
          render_error('Cannot start recruiting for this shift', :unprocessable_entity)
        end
      end

      # POST /api/v1/shifts/:id/cancel
      def cancel
        reason = params[:reason]

        if @shift.cancel!(reason)
          render json: shift_response(@shift)
        else
          render_error('Cannot cancel this shift', :unprocessable_entity)
        end
      end

      # GET /api/v1/shifts/lookup/:tracking_code
      def lookup
        if params[:tracking_code].blank?
          return render_error('Tracking code required', :bad_request)
        end

        @shift = Shift.includes(:company, :work_location, :created_by_employer)
                      .find_by!(tracking_code: params[:tracking_code].upcase)
        render json: shift_response(@shift)
      rescue ActiveRecord::RecordNotFound
        render_error('Shift not found', :not_found)
      end

      private

      def set_shift
        @shift = Shift.includes(:company, :work_location, :created_by_employer).find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error('Shift not found', :not_found)
      end

      def authorize_employer
        unless current_user.employer? && current_user.employer_profile.present?
          render_error('Only employers can perform this action', :forbidden)
        end
      end

      def authorize_shift_owner
        employer_profile = current_user.employer_profile

        unless employer_profile && @shift.company_id == employer_profile.company_id
          render_error('You do not have permission to modify this shift', :forbidden)
        end
      end

      def shift_params
        params.require(:shift).permit(
          :work_location_id,
          :title,
          :description,
          :job_type,
          :start_datetime,
          :end_datetime,
          :pay_rate_cents,
          :slots_total,
          :min_workers_needed,
          :skills_required,
          :physical_requirements
        )
      end

      def shift_response(shift)
        {
          id: shift.id,
          tracking_code: shift.tracking_code,
          company: {
            id: shift.company.id,
            name: shift.company.name
          },
          work_location: work_location_summary(shift.work_location),
          created_by: {
            id: shift.created_by_employer.id,
            name: shift.created_by_employer.full_name
          },
          title: shift.title,
          description: shift.description,
          job_type: shift.job_type,
          schedule: {
            start_datetime: shift.start_datetime,
            end_datetime: shift.end_datetime,
            duration_hours: shift.duration_hours,
            formatted_range: shift.formatted_datetime_range
          },
          pay: {
            rate_cents: shift.pay_rate_cents,
            hourly_rate: shift.hourly_rate,
            formatted_rate: shift.formatted_pay_rate,
            estimated_total: shift.estimated_pay,
            formatted_estimated: shift.formatted_estimated_pay
          },
          capacity: {
            slots_total: shift.slots_total,
            slots_filled: shift.slots_filled,
            slots_available: shift.slots_available,
            min_workers_needed: shift.min_workers_needed,
            fully_filled: shift.fully_filled?
          },
          status: shift.status,
          status_timestamps: {
            posted_at: shift.posted_at,
            recruiting_started_at: shift.recruiting_started_at,
            filled_at: shift.filled_at,
            completed_at: shift.completed_at,
            cancelled_at: shift.cancelled_at
          },
          cancellation_reason: shift.cancellation_reason,
          requirements: {
            skills_required: shift.skills_required,
            physical_requirements: shift.physical_requirements
          },
          created_at: shift.created_at,
          updated_at: shift.updated_at
        }
      end

      def work_location_summary(location)
        {
          id: location.id,
          name: location.name,
          address: location.full_address,
          city: location.city,
          state: location.state,
          zip_code: location.zip_code,
          latitude: location.latitude,
          longitude: location.longitude,
          arrival_instructions: location.arrival_instructions,
          parking_notes: location.parking_notes
        }
      end
    end
  end
end
