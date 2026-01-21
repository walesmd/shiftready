# frozen_string_literal: true

module Api
  module V1
    module Auth
      class RegistrationsController < Devise::RegistrationsController
        respond_to :json

        protected

        # Override sign_up to use sign_in without sessions (store: false)
        def sign_up(resource_name, resource)
          sign_in(resource_name, resource, store: false)
        end

        # Override build_resource to attach additional profile/company data
        def build_resource(hash = {})
          super
          # Store company and profile data as instance variables on the resource
          # so they can be accessed in the after_create callback
          if params.dig(:user, :company_attributes).present?
            resource.instance_variable_set(:@company_attributes, company_params.to_h)
          end
          if params.dig(:user, :employer_profile_attributes).present?
            resource.instance_variable_set(:@employer_profile_attributes, employer_profile_params.to_h)
          end
        rescue ActionController::ParameterMissing
          # Ignore if nested attributes aren't provided
        end

        private

        def respond_with(resource, _opts = {})
          if resource.persisted?
            render json: {
              message: "Signed up successfully.",
              user: UserSerializer.new(resource).serializable_hash[:data][:attributes]
            }, status: :created
          else
            render json: {
              message: "Sign up failed.",
              errors: resource.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        def sign_up_params
          params.require(:user).permit(:email, :password, :password_confirmation, :role)
        end

        def company_params
          params.require(:user).require(:company_attributes).permit(
            :name,
            :industry,
            :billing_address_line_1,
            :billing_city,
            :billing_state,
            :billing_zip_code,
            :workers_needed_per_week,
            :typical_roles
          )
        end

        def employer_profile_params
          params.require(:user).require(:employer_profile_attributes).permit(
            :first_name,
            :last_name,
            :title,
            :phone,
            :terms_accepted_at,
            :msa_accepted_at
          )
        end
      end
    end
  end
end
