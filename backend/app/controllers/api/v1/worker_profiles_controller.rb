# frozen_string_literal: true

module Api
  module V1
    class WorkerProfilesController < BaseController
      before_action :ensure_worker_role, only: [:create, :update]
      before_action :set_worker_profile, only: [:show, :update]

      # POST /api/v1/workers
      def create
        if current_user.worker_profile.present?
          return render_error('Worker profile already exists', :conflict)
        end

        worker_profile = current_user.build_worker_profile(worker_profile_params)

        if worker_profile.save
          render json: worker_profile_response(worker_profile), status: :created
        else
          render_errors(worker_profile.errors.full_messages)
        end
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

        if @worker_profile.update(worker_profile_params)
          render json: worker_profile_response(@worker_profile)
        else
          render_errors(@worker_profile.errors.full_messages)
        end
      end

      private

      def ensure_worker_role
        unless current_user.worker?
          render_error('Only workers can access this endpoint', :forbidden)
        end
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
    end
  end
end
