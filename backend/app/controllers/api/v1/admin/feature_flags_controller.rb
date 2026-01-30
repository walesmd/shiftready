# frozen_string_literal: true

module Api
  module V1
    module Admin
      class FeatureFlagsController < BaseController
        before_action :authorize_admin!
        before_action :set_feature_flag, only: [:show, :update, :toggle, :archive, :restore]

        # GET /api/v1/admin/feature_flags
        def index
          flags = FeatureFlag.all

          # Apply search filter
          if params[:search].present?
            sanitized_search = ActiveRecord::Base.sanitize_sql_like(params[:search].downcase)
            search_term = "%#{sanitized_search}%"
            flags = flags.where("LOWER(key) LIKE ? OR LOWER(description) LIKE ?", search_term, search_term)
          end

          # Apply status filter
          flags = case params[:status]
                  when "archived"
                    flags.archived
                  when "active"
                    flags.active
                  else
                    flags.active # Default to active
                  end

          # Pagination
          page = [params[:page].to_i, 1].max
          per_page = [[params[:per_page].to_i, 1].max, 100].min
          per_page = 20 if per_page < 1
          total_count = flags.count

          flags = flags.order(key: :asc)
                       .offset((page - 1) * per_page)
                       .limit(per_page)

          render json: {
            feature_flags: flags.map { |flag| feature_flag_response(flag) },
            meta: {
              total: total_count,
              page: page,
              per_page: per_page,
              total_pages: (total_count / per_page.to_f).ceil
            }
          }
        end

        # GET /api/v1/admin/feature_flags/:id
        def show
          audit_logs = @feature_flag.audit_logs
                                    .includes(:user)
                                    .recent
                                    .limit(50)

          render json: {
            feature_flag: feature_flag_response(@feature_flag),
            audit_logs: audit_logs.map { |log| audit_log_response(log) }
          }
        end

        # POST /api/v1/admin/feature_flags
        def create
          @feature_flag = FeatureFlag.new(feature_flag_params)

          ActiveRecord::Base.transaction do
            @feature_flag.save!
            FeatureFlagAuditLog.log_created(
              feature_flag: @feature_flag,
              user: current_user,
              value: @feature_flag.value
            )
          end

          render json: { feature_flag: feature_flag_response(@feature_flag) }, status: :created
        rescue ActiveRecord::RecordInvalid => e
          render_errors(e.record.errors.full_messages)
        end

        # PATCH /api/v1/admin/feature_flags/:id
        def update
          ActiveRecord::Base.transaction do
            @feature_flag.update!(feature_flag_params)

            # Only log audit if value or description actually changed
            changes = @feature_flag.saved_changes.slice('value', 'description')
            if changes.any?
              previous_value = changes.transform_keys(&:to_sym).transform_values(&:first)
              new_value = changes.transform_keys(&:to_sym).transform_values(&:last)

              FeatureFlagAuditLog.log_updated(
                feature_flag: @feature_flag,
                user: current_user,
                previous_value: previous_value,
                new_value: new_value
              )
            end

            FeatureService.invalidate_cache(@feature_flag.key)
          end

          render json: { feature_flag: feature_flag_response(@feature_flag) }
        rescue ActiveRecord::RecordInvalid => e
          render_errors(e.record.errors.full_messages)
        end

        # POST /api/v1/admin/feature_flags/:id/toggle
        def toggle
          unless @feature_flag.boolean?
            return render_error("Can only toggle boolean flags", :unprocessable_entity)
          end

          previous_value = { value: @feature_flag.value }
          new_value = !@feature_flag.value

          if @feature_flag.update(value: new_value)
            FeatureFlagAuditLog.log_updated(
              feature_flag: @feature_flag,
              user: current_user,
              previous_value: previous_value,
              new_value: { value: new_value }
            )

            FeatureService.invalidate_cache(@feature_flag.key)

            render json: { feature_flag: feature_flag_response(@feature_flag) }
          else
            render_errors(@feature_flag.errors.full_messages)
          end
        end

        # POST /api/v1/admin/feature_flags/:id/archive
        def archive
          if @feature_flag.archive!(user: current_user)
            FeatureService.invalidate_cache(@feature_flag.key)
            render json: { feature_flag: feature_flag_response(@feature_flag) }
          else
            render_error("Flag is already archived", :unprocessable_entity)
          end
        end

        # POST /api/v1/admin/feature_flags/:id/restore
        def restore
          if @feature_flag.restore!(user: current_user)
            FeatureService.invalidate_cache(@feature_flag.key)
            render json: { feature_flag: feature_flag_response(@feature_flag) }
          else
            render_error("Flag is not archived", :unprocessable_entity)
          end
        end

        private

        def authorize_admin!
          return if current_user.admin?

          render_error("Only admins can access this resource", :forbidden)
        end

        def set_feature_flag
          @feature_flag = FeatureFlag.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render_error("Feature flag not found", :not_found)
        end

        def feature_flag_params
          params.require(:feature_flag).permit(:key, :description, :value, :metadata)
                .tap do |fp|
                  # Parse value if it's a JSON string
                  if fp[:value].is_a?(String)
                    begin
                      fp[:value] = JSON.parse(fp[:value])
                    rescue JSON::ParserError
                      # Keep as string if not valid JSON
                    end
                  end
                end
        end

        def feature_flag_response(flag)
          {
            id: flag.id,
            key: flag.key,
            value: flag.value,
            value_type: flag.value_type,
            description: flag.description,
            archived: flag.archived,
            metadata: flag.metadata,
            created_at: flag.created_at,
            updated_at: flag.updated_at
          }
        end
        def audit_log_response(log)
          {
            id: log.id,
            action: log.action,
            previous_value: log.previous_value,
            new_value: log.new_value,
            details: log.details,
            created_at: log.created_at,
            user: log.user ? {
              id: log.user.id,
              email: log.user.email
            } : nil
          }
        end
      end
    end
  end
end
