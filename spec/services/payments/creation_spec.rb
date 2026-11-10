# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::PaymentCreationService, type: :service do
  let(:user) { create(:user, :with_full_details) }
  let!(:order) { create(:order, :with_items, items_count: 2, user: user) }

  let(:stripe_payment_intent) do
    instance_double(Stripe::PaymentIntent, id: 'pi_12345', client_secret: 'pi_12345_secret_67890',
                                           status: 'requires_payment_method')
  end

  before do
    allow_any_instance_of(CartObserver).to receive(:after_create)
    allow_any_instance_of(CartObserver).to receive(:after_update)
    allow_any_instance_of(CartObserver).to receive(:after_destroy)

    allow_any_instance_of(OrderObserver).to receive(:after_create)
    allow_any_instance_of(OrderObserver).to receive(:after_destroy)
    allow_any_instance_of(OrderObserver).to receive(:after_update)
  end

  before do
    allow(Stripe::PaymentIntent).to receive(:create).and_return(stripe_payment_intent)
    allow(Stripe::PaymentIntent).to receive(:update).and_return(stripe_payment_intent)
    allow(Stripe::PaymentIntent).to receive(:retrieve).and_return(stripe_payment_intent)
  end

  describe '.call' do
    subject(:call_service) { described_class.call(user: user, order_id: order.id) }

    context 'when order is valid and unpaid' do
      context 'and a payment intent does not yet exist' do
        it 'calls Stripe::PaymentIntent.create with correct parameters' do
          expect(Stripe::PaymentIntent).to receive(:create).with(
            amount: 19_998,
            currency: 'pln',
            metadata: { order_id: order.id }
          ).and_return(stripe_payment_intent)

          call_service
        end

        it 'updates the order with the new payment_intent_id' do
          expect { call_service }.to change { order.reload.stripe_payment_intent_id }.from(nil).to('pi_12345')
        end

        it 'returns a successful result with the client_secret' do
          result = call_service
          expect(result.success?).to be true
          expect(result.data[:client_secret]).to eq('pi_12345_secret_67890')
          expect(result.status).to eq(:ok)
        end
      end

      context 'and a payment intent already exists' do
        let!(:order) do
          create(:order, :with_items, items_count: 3, user: user).tap do |o|
            o.update_column(:stripe_payment_intent_id, 'pi_existing')
          end
        end

        it 'calls Stripe::PaymentIntent.update with correct parameters' do
          expect(Stripe::PaymentIntent).to receive(:update).with(
            'pi_existing',
            amount: 29_997,
            currency: 'pln'
          ).and_return(stripe_payment_intent)

          call_service
        end

        it 'does NOT call Stripe::PaymentIntent.create' do
          expect(Stripe::PaymentIntent).not_to receive(:create)
          call_service
        end
      end
    end

    context 'when the order is not found' do
      subject(:call_service) { described_class.call(user: user, order_id: -1) }

      it 'returns a failure result with a not_found status' do
        result = call_service
        expect(result.success?).to be false
        expect(result.status).to eq(:not_found)
      end

      it 'does not call the Stripe API' do
        expect(Stripe::PaymentIntent).not_to receive(:create)
        expect(Stripe::PaymentIntent).not_to receive(:update)
        call_service
      end
    end

    context 'when the order is already paid' do
      let(:order) { create(:order, :with_items, :paid, user: user) }

      it 'returns a failure result with an unprocessable_content status' do
        result = call_service
        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
        expect(result.errors).to include('This order has already been paid for.')
      end
    end

    context 'when the Stripe API raises an error' do
      before do
        allow(Stripe::PaymentIntent).to receive(:create).and_raise(Stripe::APIError, 'Stripe is down')
      end

      it 'returns a failure result with a service_unavailable status' do
        result = call_service
        expect(result.success?).to be false
        expect(result.status).to eq(:service_unavailable)
        expect(result.message).to eq('Stripe is down')
      end
    end

    context 'when updating the order record fails' do
      before do
        allow_any_instance_of(Order).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(order))
      end

      it 'returns a failure result with validation errors' do
        result = call_service
        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
      end
    end
  end
end
