# frozen_string_literal: true

module Services
  class StripeWebhookHandlerService
    extend Concerns::Handlers
    extend Concerns::ResultHelpers

    def self.call(payload:, sig_header:)
      with_json_parser_error_handling do
        secret_result = retrieve_endpoint_secret
        return secret_result unless secret_result.success?

        endpoint_secret = secret_result.data[:secret]

        verification_result = Services::StripeWebhookVerificationService.verify_and_construct_event(
          payload: payload,
          sig_header: sig_header,
          endpoint_secret: endpoint_secret
        )
        return verification_result unless verification_result.success?

        event = verification_result.data[:event]
        Services::StripeWebhookService.handle(event)
      end
    end

    def self.retrieve_endpoint_secret
      secret = ENV.fetch('STRIPE_WEBHOOK_SECRET')

      if secret.present?
        success_result(data: { secret: secret }, message: 'succeeded')
      else
        error_message = 'Stripe webhook secret is not configured on the server.'
        Rails.logger.error("StripeWebhookHandlerService: #{error_message}")
        internal_server_error_result(message: error_message, errors: [error_message])
      end
    end
  end
end
