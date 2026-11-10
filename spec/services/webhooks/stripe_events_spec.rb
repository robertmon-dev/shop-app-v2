# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::StripeWebhookService, type: :service do
  describe '.handle' do
    context 'with a "payment_intent.succeeded" event' do
      let!(:user) { create(:user, :with_full_details) }
      let!(:order) { create(:order, stripe_payment_intent_id: 'pi_123', user: user) }
      let(:payment_intent_object) do
        OpenStruct.new(
          id: 'pi_123',
          amount_received: 5000,
          currency: 'pln',
          latest_charge: OpenStruct.new(
            id: 'ch_456',
            payment_method_details: OpenStruct.new(
              type: 'card',
              card: OpenStruct.new(brand: 'visa')
            )
          )
        )
      end
      let(:event) do
        OpenStruct.new(type: 'payment_intent.succeeded', data: OpenStruct.new(object: payment_intent_object))
      end

      it 'creates a new Payment record' do
        expect { described_class.handle(event) }.to change(Payment, :count).by(1)
      end

      it 'marks the associated order as paid' do
        described_class.handle(event)
        expect(order.reload.payment_status_paid?).to be true
      end

      it 'returns a successful result' do
        result = described_class.handle(event)
        expect(result.success?).to be true
        expect(result.status).to eq(:ok)
      end

      context 'when the order is already paid' do
        before { order.update!(payment_status: :paid) }

        it 'does not create a new payment and takes no action' do
          expect { described_class.handle(event) }.not_to change(Payment, :count)
          expect(order).not_to receive(:mark_as_paid!)
        end
      end
    end

    context 'with a "payment_intent.payment_failed" event' do
      let!(:order) { create(:order, stripe_payment_intent_id: 'pi_failed_123') }
      let(:payment_intent_object) { OpenStruct.new(id: 'pi_failed_123') }
      let(:event) do
        OpenStruct.new(type: 'payment_intent.payment_failed', data: OpenStruct.new(object: payment_intent_object))
      end

      it 'updates the order payment status to failed' do
        described_class.handle(event)
        expect(order.reload.payment_status_failed?).to be true
      end
    end

    context 'with a "charge.refunded" event' do
      let!(:order) { create(:order) }
      let!(:payment) { create(:payment, :paid, order: order, stripe_charge_id: 'ch_123') }
      let(:charge_object) { OpenStruct.new(id: 'ch_123') }
      let(:event) { OpenStruct.new(type: 'charge.refunded', data: OpenStruct.new(object: charge_object)) }

      it 'updates the payment status to refunded' do
        described_class.handle(event)
        expect(payment.reload.status_refunded?).to be true
      end

      it 'updates the order payment status to refunded' do
        described_class.handle(event)
        expect(order.reload.payment_status_refunded?).to be true
      end
    end

    context 'with an unhandled event type' do
      let(:event) { OpenStruct.new(type: 'customer.subscription.created', data: OpenStruct.new(object: {})) }

      it 'logs an info message' do
        expect(Rails.logger).to receive(:info).with(/Unhandled event type/)
        described_class.handle(event)
      end

      it 'returns a successful result (no action needed is not an error)' do
        result = described_class.handle(event)
        expect(result.success?).to be true
        expect(result.status).to eq(:ok)
      end
    end

    context 'when an unexpected error occurs' do
      let(:event) do
        OpenStruct.new(type: 'payment_intent.succeeded', id: 'evt_error', data: OpenStruct.new(object: {}))
      end

      before do
        allow(Order).to receive(:find_by).and_raise(StandardError, 'Database is down')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/An unexpected error occurred: undefined method 'id' for an instance of Hash/)
        described_class.handle(event)
      end

      it 'returns an internal_server_error failure result' do
        result = described_class.handle(event)
        expect(result.success?).to be false
        expect(result.status).to eq(:internal_server_error)
      end
    end
  end
end
