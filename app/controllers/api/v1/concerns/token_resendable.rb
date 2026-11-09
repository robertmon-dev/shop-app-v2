# frozen_string_literal: true

module Api
  module V1
    module Concerns
      module TokenResendable
        extend ActiveSupport::Concern

        MESSAGE_VIEW = 'shared/message'

        def request_2fa_code_resend
          render_auth(Services::AuthenticationService.send_2fa_code(@user), MESSAGE_VIEW)
        end

        def request_activation_code_resend
          return render_already_done(:activated) unless @user.unactivated?

          render_auth(Services::UserManagementService.resend_activation_code(@user), MESSAGE_VIEW)
        end

        def request_verification_code_resend
          return render_already_done(:verified) unless @user.unverified?

          render_auth(Services::UserManagementService.resend_verification_code(@user), MESSAGE_VIEW)
        end

        def request_reset_code_resend
          render_auth(Services::PasswordResetService.request(params[:mail]), MESSAGE_VIEW)
        end

        private

        def render_already_done(state)
          render json: { errors: ["User is already #{state}."], message: "User is already #{state}." },
                 status: :not_acceptable
        end
      end
    end
  end
end
