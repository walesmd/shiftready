# frozen_string_literal: true

module Api
  module V1
    class CompaniesController < BaseController
      before_action :set_company, only: [:show, :update]
      before_action :authorize_employer, only: [:create, :update]
      before_action :authorize_company_member, only: [:update]

      # GET /api/v1/companies
      def index
        companies = Company.active

        # Employers see only their company
        if current_user.employer? && current_user.employer_profile.present?
          companies = companies.where(id: current_user.employer_profile.company_id)
        end

        # Admins see all companies
        companies = companies.order(:name).limit(100)

        render json: {
          companies: companies.map { |company| company_response(company) },
          meta: {
            total: companies.count
          }
        }
      end

      # GET /api/v1/companies/:id
      def show
        render json: company_response(@company)
      end

      # POST /api/v1/companies
      def create
        company = Company.new(company_params)

        if company.save
          render json: company_response(company), status: :created
        else
          render_errors(company.errors.full_messages)
        end
      end

      # PATCH /api/v1/companies/:id
      def update
        if @company.update(company_params)
          render json: company_response(@company)
        else
          render_errors(@company.errors.full_messages)
        end
      end

      private

      def set_company
        @company = Company.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_error('Company not found', :not_found)
      end

      def authorize_employer
        unless current_user.employer? || current_user.admin?
          render_error('Only employers or admins can perform this action', :forbidden)
        end
      end

      def authorize_company_member
        if current_user.employer? && current_user.employer_profile.present?
          unless current_user.employer_profile.company_id == @company.id
            render_error('You do not have permission to modify this company', :forbidden)
          end
        elsif !current_user.admin?
          render_error('Only company members or admins can modify this company', :forbidden)
        end
      end

      def company_params
        params.require(:company).permit(
          :name,
          :industry,
          :billing_email,
          :billing_phone,
          :billing_address_line_1,
          :billing_address_line_2,
          :billing_city,
          :billing_state,
          :billing_zip_code,
          :tax_id,
          :payment_terms,
          :is_active
        )
      end

      def company_response(company)
        {
          id: company.id,
          name: company.name,
          industry: company.industry,
          billing_info: {
            email: company.billing_email,
            phone: company.billing_phone,
            address: company.full_billing_address
          },
          tax_info: {
            tax_id: company.tax_id,
            payment_terms: company.payment_terms
          },
          is_active: company.is_active,
          created_at: company.created_at,
          updated_at: company.updated_at
        }
      end
    end
  end
end
