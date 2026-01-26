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

        if current_user.employer?
          employer_profile = current_user.employer_profile
          return render_error('Employer profile not found', :forbidden) unless employer_profile

          companies = companies.where(id: employer_profile.company_id)
        end

        total_count = companies.count
        page = params[:page].to_i
        page = 1 if page < 1
        per_page = params[:per_page].to_i
        per_page = 100 if per_page < 1
        per_page = 200 if per_page > 200

        companies = company_with_shift_aggregates_scope(companies)
                    .order(:name)
                    .offset((page - 1) * per_page)
                    .limit(per_page)

        render json: {
          companies: companies.map { |company| company_response(company) },
          meta: {
            total: total_count,
            page: page,
            per_page: per_page,
            total_pages: (total_count / per_page.to_f).ceil
          }
        }
      end

      # GET /api/v1/companies/:id
      def show
        render json: company_response(company_with_shift_aggregates(@company))
      end

      # POST /api/v1/companies
      def create
        company = Company.new(company_params)

        if company.save
          render json: company_response(company_with_shift_aggregates(company)), status: :created
        else
          render_errors(company.errors.full_messages)
        end
      end

      # PATCH /api/v1/companies/:id
      def update
        if @company.update(company_params)
          render json: company_response(company_with_shift_aggregates(@company))
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
          :billing_latitude,
          :billing_longitude,
          :tax_id,
          :payment_terms,
          :is_active
        )
      end

      def company_response(company)
        attributes = company.attributes

        {
          id: company.id,
          name: company.name,
          industry: company.industry,
          billing_info: {
            email: company.billing_email,
            phone: company.billing_phone_display,
            address: company.full_billing_address,
            address_line_1: company.billing_address_line_1,
            address_line_2: company.billing_address_line_2,
            city: company.billing_city,
            state: company.billing_state,
            zip_code: company.billing_zip_code,
            latitude: company.billing_latitude,
            longitude: company.billing_longitude
          },
          tax_info: {
            tax_id: company.tax_id,
            payment_terms: company.payment_terms
          },
          owner: company.owner_employer_profile ? {
            id: company.owner_employer_profile.id,
            full_name: company.owner_employer_profile.full_name
          } : nil,
          is_active: company.is_active,
          shift_summary: {
            total: attributes['total_shift_count'].to_i,
            active: attributes['active_shift_count'].to_i,
            by_status: {
              posted: attributes['posted_shift_count'].to_i,
              recruiting: attributes['recruiting_shift_count'].to_i,
              in_progress: attributes['in_progress_shift_count'].to_i
            }
          },
          last_shift_requested_at: attributes['last_shift_requested_at'],
          created_at: company.created_at,
          updated_at: company.updated_at
        }
      end

      def company_with_shift_aggregates(company)
        company_with_shift_aggregates_scope(Company.where(id: company.id)).first || company
      end

      def company_with_shift_aggregates_scope(scope)
        active_status_ids = Shift.statuses.slice('posted', 'recruiting', 'in_progress').values
        active_statuses_sql = active_status_ids.join(', ')
        posted_status_id = Shift.statuses['posted']
        recruiting_status_id = Shift.statuses['recruiting']
        in_progress_status_id = Shift.statuses['in_progress']

        scope.includes(:owner_employer_profile)
             .left_joins(:shifts)
             .select(
               'companies.*',
               'MAX(shifts.created_at) AS last_shift_requested_at',
               "COUNT(CASE WHEN shifts.status IN (#{active_statuses_sql}) THEN 1 END) AS active_shift_count",
               'COUNT(shifts.id) AS total_shift_count',
               "COUNT(CASE WHEN shifts.status = #{posted_status_id} THEN 1 END) AS posted_shift_count",
               "COUNT(CASE WHEN shifts.status = #{recruiting_status_id} THEN 1 END) AS recruiting_shift_count",
               "COUNT(CASE WHEN shifts.status = #{in_progress_status_id} THEN 1 END) AS in_progress_shift_count"
             )
             .group('companies.id')
      end
    end
  end
end
