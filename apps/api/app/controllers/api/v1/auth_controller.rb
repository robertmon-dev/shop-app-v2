# frozen_string_literal: true

require 'jwt'

module Api
  module V1
    class AuthController < Api::ApplicationController
      include Api::V1::Concerns::TokenResendable

      skip_before_action :authenticate_user!, except: %i[blacklist_user whitelist_user]
      before_action :authorize_admin!, only: %i[blacklist_user whitelist_user]
      before_action :set_user_by_mail, only: %i[
        verify_2fa activate verify
        request_2fa_code_resend request_activation_code_resend request_verification_code_resend
      ]

      def login = respond_with(Auth::Authentication.login(params[:mail], params[:password]), :login)
      def verify_2fa = respond_with(Auth::Authentication.verify_2fa(@user, code(:second_factor)), :verify_2fa)
      def activate = respond_with(Users::Management.activate(@user, code(:activation)), :user)
      def verify = respond_with(Users::Management.verify(@user, code(:verification)), :user)
      def request_reset = respond_with_message(Auth::PasswordReset.request(params[:mail]))
      def confirm_reset = respond_with_message(Auth::PasswordReset.reset(*reset_args))
      def blacklist_user = respond_with_message(Users::Management.blacklist_user(id: user_id))
      def whitelist_user = respond_with_message(Users::Management.whitelist_user(id: user_id))

      private

      def code(kind) = params[:"#{kind}_code"]
      def user_id = params[:user_id]
      def reset_args = [params[:reset_code], params[:password], params[:password_confirmation]]
    end
  end
end
