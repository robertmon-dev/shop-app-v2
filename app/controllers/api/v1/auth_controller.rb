# frozen_string_literal: true

require 'jwt'

module Api
  module V1
    class AuthController < Api::ApplicationController
      include Api::V1::Concerns::TokenResendable

      skip_before_action :authenticate_user!
      before_action :set_user_by_mail, only: %i[
        verify_2fa activate verify
        request_2fa_code_resend request_activation_code_resend request_verification_code_resend
      ]

      def login = render_auth(Services::AuthenticationService.login(params[:mail], params[:password]), :login)
      def verify_2fa = render_auth(Services::AuthenticationService.verify_2fa(@user, code(:second_factor)), :verify_2fa)
      def activate = render_auth(Services::UserManagementService.activate(@user, code(:activation)), :activate)
      def verify = render_auth(Services::UserManagementService.verify(@user, code(:verification)), :verify)
      def request_reset = render_auth(Services::PasswordResetService.request(params[:mail]), :request_reset)
      def confirm_reset = render_auth(Services::PasswordResetService.reset(*reset_args), :confirm_reset)
      def blacklist_user = render_auth(Services::UserManagementService.blacklist_user(id: user_id), 'shared/message')
      def whitelist_user = render_auth(Services::UserManagementService.whitelist_user(id: user_id), 'shared/message')

      private

      def render_auth(result, view)
        bind_data(result)
        assign_resources
        render view, status: @status, locals: { token: @token }
      end

      def code(kind) = params[:"#{kind}_code"]
      def user_id = params[:user_id]
      def reset_args = [params[:reset_code], params[:password], params[:password_confirmation]]
    end
  end
end
