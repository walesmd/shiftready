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
        if current_user.update(user_params)
          render json: {
            message: "Profile updated successfully.",
            user: UserSerializer.new(current_user).serializable_hash[:data][:attributes]
          }, status: :ok
        else
          render_errors(current_user.errors.full_messages)
        end
      end

      private

      def user_params
        params.require(:user).permit(:email)
      end
    end
  end
end
