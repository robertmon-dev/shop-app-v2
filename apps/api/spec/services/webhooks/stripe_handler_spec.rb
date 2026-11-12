# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::StripeHandler, type: :service do
  subject(:call_service) { described_class.call(payload: payload, sig_header: sig_header) }

  let(:payload) { { id: 'evt_123' }.to_json }
  let(:sig_header) { 't=123,v1=abc' }
  let(:endpoint_secret) { ENV.fetch('STRIPE_WEBHOOK_SECRET') }

  let(:stripe_event) { instance_double(Stripe::Event) }

  let(:verification_success_result) { ApplicationService::Result.new(success?: true, data: { event: stripe_event }) }
  let(:verification_failure_result) { ApplicationService::Result.new(success?: false, errors: ['Invalid signature']) }
  let(:processing_success_result) { ApplicationService::Result.new(success?: true, message: 'Processed') }

  before do
    allow(Rails.application.credentials).to receive(:stripe).and_return({ webhook_secret: endpoint_secret })

    allow(Webhooks::StripeVerification).to receive(:verify_and_construct_event)
    allow(Webhooks::StripeEvents).to receive(:handle)
  end

  describe '.call' do
    context 'when webhook verification fails' do
      before do
        allow(Webhooks::StripeVerification).to receive(:verify_and_construct_event)
          .and_return(verification_failure_result)
      end

      it 'returns the failure result from the verification service' do
        expect(call_service).to eq(verification_failure_result)
      end

      it 'does not call the processing service' do
        call_service
        expect(Webhooks::StripeEvents).not_to have_received(:handle)
      end
    end

    context 'when webhook verification succeeds' do
      before do
        allow(Webhooks::StripeVerification).to receive(:verify_and_construct_event)
          .and_return(verification_success_result)

        allow(Webhooks::StripeEvents).to receive(:handle)
          .with(stripe_event)
          .and_return(processing_success_result)
      end

      it 'calls the verification service with correct parameters' do
        call_service
        expect(Webhooks::StripeVerification).to have_received(:verify_and_construct_event)
          .with(payload: payload, sig_header: sig_header, endpoint_secret: endpoint_secret)
      end

      it 'calls the processing service with the event from the verification result' do
        call_service
        expect(Webhooks::StripeEvents).to have_received(:handle).with(stripe_event)
      end

      it 'returns the result from the processing service' do
        expect(call_service).to eq(processing_success_result)
      end
    end

    context 'when STRIPE_WEBHOOK_SECRET is not configured' do
      it 'returns a clear server error instead of raising' do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('STRIPE_WEBHOOK_SECRET', nil).and_return(nil)

        result = described_class.call(payload: '{}', sig_header: 'sig')

        expect(result.success?).to be false
        expect(result.status).to eq(:internal_server_error)
        expect(result.message).to include('not configured')
      end
    end
  end
end
