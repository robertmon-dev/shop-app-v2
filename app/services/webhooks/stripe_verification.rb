# frozen_string_literal: true

module Webhooks
  class StripeVerification < ApplicationService
    def self.verify_and_construct_event(payload:, sig_header:, endpoint_secret:)
      unless endpoint_secret
        return internal_server_error_result(message: 'No endpoint secret provided',
                                            errors: ['No endpoint secrets provided'])
      end

      with_json_parser_error_handling do
        event = Stripe::Webhook.construct_event(
          payload, sig_header, endpoint_secret
        )
        success_result(data: { event: event }, message: 'Webhook event verified successfully')
      end
    end
  end
end
