# frozen_string_literal: true

module Api
  module V1
    class UsersController < Api::ApplicationController
      skip_before_action :authenticate_user!, only: [:create]
      load_and_authorize_resource except: %i[create me logout]

      def index = respond_with_view(:index, users: @users.page(params[:page]).per(25))
      def show = respond_with_view(:show)
      def me = respond_with_view(:show, user: current_user)
      def actions = respond_with_view(:actions, actions: @user.user_actions.page(params[:page]).per(25))
      def create = respond_with(Users::Creation.call(user_params))
      def update = respond_with(user_profile_service.update_profile(user_params))
      def update_location = respond_with(user_profile_service.update_location(location_params))
      def update_details = respond_with(user_profile_service.update_details(user_detail_params))
      def role = respond_with(user_profile_service.update_role(params[:role]))
      def destroy = respond_with_destroy(user_profile_service.destroy_user)

      def update_entrepreneur_details
        respond_with(user_profile_service.update_entrepreneur_details(entrepreneur_detail_params))
      end

      def logout
        authorize! :logout, current_user
        respond_with_message(Auth::Authentication.blacklist_token(bearer_token))
      end

      private

      def user_profile_service
        @user_profile_service ||= Users::Profile.new(@user)
      end

      def user_params
        params.require(:user).permit(
          :mail, :password, :password_confirmation, :phone,
          user_detail_attributes: %i[name first_name last_name]
        )
      end

      def location_params
        params.require(:location).permit(
          :country, :province, :city, :postal_code, :street,
          :building_number, :apartment_number
        )
      end

      def user_detail_params = params.require(:user_detail).permit(:name, :first_name, :last_name)

      def entrepreneur_detail_params
        params.require(:entrepreneur_detail).permit(
          :business_name, :nip, :krs, :description, :offer, :income, :costs,
          :funding_capital, :industry, :business_phone_number, :business_mail,
          :website_address,
          management_council_members: {},
          decision_makers: {}
        )
      end
    end
  end
end
