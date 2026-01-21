# frozen_string_literal: true

module Api
  module V1
    class EmployerProfilesController < BaseController
      before_action :ensure_employer_role, only: [:create, :update]
      before_action :set_employer_profile, only: [:show, :update]

      # POST /api/v1/employers
      def create
        if current_user.employer_profile.present?
          return render_error('Employer profile already exists', :conflict)
        end

        employer_profile = current_user.build_employer_profile(employer_profile_params)

        if employer_profile.save
          render json: employer_profile_response(employer_profile), status: :created
        else
          render_errors(employer_profile.errors.full_messages)
        end
      end

      # GET /api/v1/employers/me
      def show
        if @employer_profile
          render json: employer_profile_response(@employer_profile)
        else
          render_error('Employer profile not found', :not_found)
        end
      end

      # PATCH /api/v1/employers/me
      def update
        unless @employer_profile
          return render_error('Employer profile not found', :not_found)
        end

        if @employer_profile.update(employer_profile_params)
          render json: employer_profile_response(@employer_profile)
        else
          render_errors(@employer_profile.errors.full_messages)
        end
      end

      private

      def ensure_employer_role
        unless current_user.employer?
          render_error('Only employers can access this endpoint', :forbidden)
        end
      end

      def set_employer_profile
        @employer_profile = current_user.employer_profile
      end

      def employer_profile_params
        params.require(:employer_profile).permit(
          :company_id,
          :first_name,
          :last_name,
          :title,
          :phone,
          :terms_accepted_at,
          :msa_accepted_at,
          :can_post_shifts,
          :can_approve_timesheets,
          :is_billing_contact
        )
      end

      def employer_profile_response(profile)
        {
          id: profile.id,
          user_id: profile.user_id,
          company_id: profile.company_id,
          company: profile.company ? company_summary(profile.company) : nil,
          first_name: profile.first_name,
          last_name: profile.last_name,
          full_name: profile.full_name,
          title: profile.title,
          phone: profile.phone,
          onboarding_completed: profile.onboarding_completed,
          terms_accepted_at: profile.terms_accepted_at,
          msa_accepted_at: profile.msa_accepted_at,
          permissions: {
            can_post_shifts: profile.can_post_shifts,
            can_approve_timesheets: profile.can_approve_timesheets,
            is_billing_contact: profile.is_billing_contact
          },
          created_at: profile.created_at,
          updated_at: profile.updated_at
        }
      end

      def company_summary(company)
        {
          id: company.id,
          name: company.name,
          industry: company.industry,
          is_active: company.is_active
        }
      end
    end
  end
end
