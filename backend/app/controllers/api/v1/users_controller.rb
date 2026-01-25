# frozen_string_literal: true

module Api
  module V1
    class UsersController < BaseController
      # GET /api/v1/auth/me
      def me
        render json: {
          user: UserSerializer.new(current_user).serializable_hash[:data][:attributes]
        }, status: :ok
      end

      # PATCH /api/v1/auth/me
      def update_me
        # Handle password change separately
        if password_change_requested?
          handle_password_change
        else
          # Handle regular profile updates (email, etc.)
          if current_user.update(user_params)
            render json: {
              message: "Profile updated successfully.",
              user: UserSerializer.new(current_user).serializable_hash[:data][:attributes]
            }, status: :ok
          else
            render_errors(current_user.errors.full_messages)
          end
        end
      end

      private

      def password_change_requested?
        params[:user]&.dig(:current_password).present? ||
          params[:user]&.dig(:password).present? ||
          params[:user]&.dig(:password_confirmation).present?
      end

      def handle_password_change
        # Validate that current password is provided
        unless params[:user][:current_password].present?
          return render_error("Current password is required", :unprocessable_entity)
        end

        # Verify current password
        unless current_user.valid_password?(params[:user][:current_password])
          return render_error("Current password is incorrect", :unprocessable_entity)
        end

        # Validate new password and confirmation are provided
        unless params[:user][:password].present? && params[:user][:password_confirmation].present?
          return render_error("New password and confirmation are required", :unprocessable_entity)
        end

        # Update password
        if current_user.update(password_params)
          # Regenerate JTI to invalidate old tokens
          current_user.update_column(:jti, SecureRandom.uuid)

          render json: {
            message: "Password updated successfully."
          }, status: :ok
        else
          render_errors(current_user.errors.full_messages)
        end
      end

      def user_params
        params.require(:user).permit(:email)
      end

      def password_params
        params.require(:user).permit(:password, :password_confirmation)
      end
    end
  end
end
