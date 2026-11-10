# frozen_string_literal: true

require 'swagger_helper'

describe 'Stripe Webhooks API' do
  path '/api/v1/stripe_payments_webhook/handle' do
    post 'Handles incoming webhooks from Stripe' do
      tags 'Webhooks'
      consumes 'application/json'
      produces 'application/json'
      description 'Receives and processes asynchronous events from Stripe. The request body should be the raw JSON payload from Stripe, and the `Stripe-Signature` header must be present.'

      parameter name: 'Stripe-Signature', in: :header, type: :string, required: true
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          id: { type: :string, example: 'evt_12345' },
          type: { type: :string, example: 'charge.succeeded' },
          data: { type: :object }
        }
      }

      let(:payload) { { id: 'evt_12345', type: 'charge.succeeded', data: {} }.to_json }
      let(:'Stripe-Signature') { 't=1492774577,v1=...,v0=...' }

      context 'with a valid payload and signature' do
        before do
          allow(Webhooks::StripeHandler).to receive(:call).and_return(
            ApplicationService::Result.new(success?: true, status: :ok, message: 'Webhook received and processed.')
          )
        end

        response '200', 'webhook processed successfully' do
          schema type: :object, properties: {
            success: { type: :boolean, example: true },
            message: { type: :string }
          }
          run_test!
        end
      end

      context 'with an invalid signature' do
        before do
          allow(Webhooks::StripeHandler).to receive(:call).and_return(
            ApplicationService::Result.new(success?: false, status: :bad_request, errors: ['Invalid signature'])
          )
        end

        response '400', 'invalid signature' do
          schema type: :object, properties: {
            success: { type: :boolean, example: false },
            errors: { type: :array, items: { type: :string } }
          }
          run_test!
        end
      end

      context 'with a server error during processing' do
        before do
          allow(Webhooks::StripeHandler).to receive(:call).and_return(
            ApplicationService::Result.new(success?: false, status: :internal_server_error, errors: ['Webhook processing failed'])
          )
        end

        response '500', 'internal server error' do
          schema type: :object, properties: {
            success: { type: :boolean, example: false },
            errors: { type: :array, items: { type: :string } }
          }
          run_test!
        end
      end
    end
  end
end
