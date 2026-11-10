# frozen_string_literal: true

module Api
  module V1
    class StripePaymentsWebhookController < Api::ApplicationController
      skip_before_action :authenticate_user!

      def handle = respond_with_message(Webhooks::StripeHandler.call(**webhook_args))

      private

      def webhook_args
        { payload: request.body.read, sig_header: request.env['HTTP_STRIPE_SIGNATURE'] }
      end
    end
  end
end
