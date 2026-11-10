# frozen_string_literal: true

module Api
  module V1
    module Concerns
      module TokenResendable
        extend ActiveSupport::Concern

        def request_2fa_code_resend
          respond_with_message(Auth::Authentication.resend_2fa_code(@user))
        end

        def request_activation_code_resend
          return render_already_done(:activated) unless @user.unactivated?

          respond_with_message(Users::Management.resend_activation_code(@user))
        end

        def request_verification_code_resend
          return render_already_done(:verified) unless @user.unverified?

          respond_with_message(Users::Management.resend_verification_code(@user))
        end

        def request_reset_code_resend
          respond_with_message(Auth::PasswordReset.request(params[:mail]))
        end

        private

        def render_already_done(state)
          render_failure(message: "User is already #{state}.", status: :not_acceptable)
        end
      end
    end
  end
end
