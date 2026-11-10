# frozen_string_literal: true

module Webhooks
  class StripeHandler < ApplicationService
    def initialize(payload:, sig_header:)
      @payload = payload
      @sig_header = sig_header
    end

    def call
      with_json_parser_error_handling do
        secret_result = endpoint_secret
        next secret_result unless secret_result.success?

        verification = StripeVerification.verify_and_construct_event(
          payload: @payload, sig_header: @sig_header, endpoint_secret: secret_result.data[:secret]
        )
        verification.success? ? StripeEvents.handle(verification.data[:event]) : verification
      end
    end

    private

    def endpoint_secret
      secret = ENV.fetch('STRIPE_WEBHOOK_SECRET')
      return success_result(data: { secret: secret }, message: 'succeeded') if secret.present?

      message = 'Stripe webhook secret is not configured on the server.'
      Rails.logger.error("Webhooks::StripeHandler: #{message}")
      internal_server_error_result(message: message, errors: [message])
    end
  end
end
