# frozen_string_literal: true

module Api
  module V1
    class N8nWebhookController < Api::ApplicationController
      skip_before_action :authenticate_user!
      before_action :verify_webhook_secret

      def handle = respond_with(Webhooks::N8nHandler.call(webhook_params), :handle)

      private

      def webhook_params
        params.permit(:event, :order_id, :tracking_id, :shipping_service_id, :notes)
      end

      def verify_webhook_secret
        expected = ENV.fetch('N8N_WEBHOOK_SECRET', nil)
        return if expected.present? && ActiveSupport::SecurityUtils.secure_compare(provided_secret, expected)

        render json: { errors: ['Invalid webhook signature.'] }, status: :unauthorized
      end

      def provided_secret = request.headers['X-N8N-Signature'].to_s
    end
  end
end
