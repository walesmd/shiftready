# frozen_string_literal: true

module Api
  module V1
    class WorkLocationsController < BaseController
      before_action :set_work_location, only: [:show, :update, :destroy]
      before_action :authorize_employer, only: [:create, :update, :destroy]
      before_action :authorize_company_location, only: [:update, :destroy]

      # GET /api/v1/work_locations
      def index
        locations = WorkLocation.active

        # Filter by company if specified
        locations = locations.where(company_id: params[:company_id]) if params[:company_id].present?

        # Employers see only their company's locations
        if current_user.employer? && current_user.employer_profile.present?
          locations = locations.where(company_id: current_user.employer_profile.company_id)
        end

        locations = locations.order(:name).limit(100)

        render json: {
          work_locations: locations.map { |location| work_location_response(location) },
          meta: {
            total: locations.count
          }
        }
      end

      # GET /api/v1/work_locations/:id
      def show
        render json: work_location_response(@work_location)
      end

      # POST /api/v1/work_locations
      def create
        employer_profile = current_user.employer_profile

        unless employer_profile
          return render_error('Employer profile required', :forbidden)
        end

        location = employer_profile.company.work_locations.build(work_location_params)

        if location.save
          render json: work_location_response(location), status: :created
        else
          render_errors(location.errors.full_messages)
        end
      end

      # PATCH /api/v1/work_locations/:id
      def update
        if @work_location.update(work_location_params)
          render json: work_location_response(@work_location)
        else
          render_errors(@work_location.errors.full_messages)
        end
      end

      # DELETE /api/v1/work_locations/:id
      def destroy
        if @work_location.shifts.exists?
          render_error('Cannot delete location with existing shifts', :unprocessable_entity)
        else
          @work_location.destroy
          head :no_content
        end
      end

      private

      def set_work_location
        @work_location = WorkLocation.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error('Work location not found', :not_found)
      end

      def authorize_employer
        unless current_user.employer? && current_user.employer_profile.present?
          render_error('Only employers can perform this action', :forbidden)
        end
      end

      def authorize_company_location
        employer_profile = current_user.employer_profile

        unless employer_profile && @work_location.company_id == employer_profile.company_id
          render_error('You do not have permission to modify this location', :forbidden)
        end
      end

      def work_location_params
        params.require(:work_location).permit(
          :name,
          :address_line_1,
          :address_line_2,
          :city,
          :state,
          :zip_code,
          :latitude,
          :longitude,
          :arrival_instructions,
          :parking_notes,
          :is_active
        )
      end

      def work_location_response(location)
        {
          id: location.id,
          company_id: location.company_id,
          name: location.name,
          address: {
            line_1: location.address_line_1,
            line_2: location.address_line_2,
            city: location.city,
            state: location.state,
            zip_code: location.zip_code,
            full_address: location.full_address
          },
          coordinates: {
            latitude: location.latitude,
            longitude: location.longitude
          },
          instructions: {
            arrival: location.arrival_instructions,
            parking: location.parking_notes
          },
          is_active: location.is_active,
          display_name: location.display_name,
          created_at: location.created_at,
          updated_at: location.updated_at
        }
      end
    end
  end
end
