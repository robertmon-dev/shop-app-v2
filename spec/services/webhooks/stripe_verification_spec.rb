# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::StripeWebhookVerificationService, type: :service do
  let(:payload) { { id: 'evt_123', type: 'charge.succeeded' }.to_json }
  let(:sig_header) { 't=1492774577,v1=...,v0=...' }
  let(:endpoint_secret) { 'whsec_...' }
  let(:stripe_webhook) { class_double(Stripe::Webhook) }

  before do
    stub_const('Stripe::Webhook', stripe_webhook)
    allow(Rails.logger).to receive(:error)
  end

  describe '.verify_and_construct_event' do
    context 'with a valid payload and signature' do
      let(:stripe_event) { Stripe::Event.construct_from(JSON.parse(payload)) }

      before do
        allow(stripe_webhook).to receive(:construct_event).and_return(stripe_event)
      end

      it 'calls Stripe::Webhook.construct_event with the correct arguments' do
        expect(stripe_webhook).to receive(:construct_event).with(payload, sig_header, endpoint_secret)
        described_class.verify_and_construct_event(payload: payload, sig_header: sig_header,
                                                   endpoint_secret: endpoint_secret)
      end

      it 'returns a successful result with the event data' do
        result = described_class.verify_and_construct_event(payload: payload, sig_header: sig_header,
                                                            endpoint_secret: endpoint_secret)
        expect(result.success?).to be true
        expect(result.status).to eq(:ok)
        expect(result.data[:event]).to eq(stripe_event)
      end
    end

    context 'when the payload is invalid JSON' do
      before do
        allow(stripe_webhook).to receive(:construct_event).and_raise(JSON::ParserError.new('invalid json'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Stripe Webhook Error: Invalid payload/)
        described_class.verify_and_construct_event(payload: 'invalid', sig_header: sig_header,
                                                   endpoint_secret: endpoint_secret)
      end

      it 'returns a bad_request failure result' do
        result = described_class.verify_and_construct_event(payload: 'invalid', sig_header: sig_header,
                                                            endpoint_secret: endpoint_secret)
        expect(result.success?).to be false
        expect(result.status).to eq(:bad_request)
        expect(result.errors.first).to eq('Invalid webhook payload')
      end
    end

    context 'when the signature is invalid' do
      before do
        allow(stripe_webhook).to receive(:construct_event).and_raise(Stripe::SignatureVerificationError.new(
                                                                       'verification failed', sig_header
                                                                     ))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Stripe Webhook Error: Signature verification failed/)
        described_class.verify_and_construct_event(payload: payload, sig_header: 'invalid',
                                                   endpoint_secret: endpoint_secret)
      end

      it 'returns a bad_request failure result' do
        result = described_class.verify_and_construct_event(payload: payload, sig_header: 'invalid',
                                                            endpoint_secret: endpoint_secret)
        expect(result.success?).to be false
        expect(result.status).to eq(:bad_request)
        expect(result.errors).to include('Stripe signature verification failed.')
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(stripe_webhook).to receive(:construct_event).and_raise(StandardError.new('unexpected issue'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/An unexpected error occurred: unexpected issue/)
        described_class.verify_and_construct_event(payload: payload, sig_header: sig_header,
                                                   endpoint_secret: endpoint_secret)
      end

      it 'returns an internal_server_error failure result' do
        result = described_class.verify_and_construct_event(payload: payload, sig_header: sig_header,
                                                            endpoint_secret: endpoint_secret)
        expect(result.success?).to be false
        expect(result.status).to eq(:internal_server_error)
      end
    end
  end
end
