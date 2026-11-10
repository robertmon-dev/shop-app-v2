# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::OrderCreationService, type: :service do
  describe '#call' do
    let!(:user) { create(:user, :with_detail) }
    let!(:location) { user.user_detail.locations.create(attributes_for(:location)) }
    let(:product) { create(:product, price: 10.00) }
    let(:cart_item_ids) { [] }

    subject(:call_service) do
      described_class.call(user: user, package_carrier: :inpost, location_id: location.id, cart_item_ids: cart_item_ids)
    end

    context 'when the cart is empty' do
      it 'returns a failure result and does not create an order' do
        expect { call_service }.not_to change(Order, :count)

        result = call_service

        expect(result.success?).to be false
        expect(result.errors).to include('Your cart is empty or no items were selected.')
        expect(result.status).to eq(:unprocessable_content)
      end
    end

    context 'when creating an order from the entire cart' do
      let!(:cart_item) { create(:cart_item, user: user, product: product, quantity: 2) }

      it 'creates an order with all items and returns a success result' do
        result = nil
        expect { result = call_service }.to change(Order, :count).by(1)

        expect(result.success?).to be true
        expect(result.data[:order]).to be_a(Order)
        expect(result.status).to eq(:created)
      end

      it 'clears all items from the cart' do
        call_service
        expect(user.reload.cart_items).to be_empty
      end

      it 'creates corresponding order items for the new order' do
        result = call_service
        order = result.data[:order]

        expect(order.items.count).to eq(1)
        expect(order.items.first.product).to eq(product)
        expect(order.items.first.quantity).to eq(2)
        expect(order.items.first.price_at_purchase).to eq(product.price)
      end
    end

    context 'when creating an order from selected cart items' do
      let!(:cart_item_to_order) { create(:cart_item, user: user, product: product, quantity: 1) }
      let!(:cart_item_to_keep) { create(:cart_item, user: user, product: create(:product), quantity: 3) }
      let(:cart_item_ids) { [cart_item_to_order.id] }

      it 'creates an order and returns a success result' do
        expect { call_service }.to change(Order, :count).by(1)
        expect(call_service.success?).to be true
      end

      it 'only moves the selected item from the cart to the order' do
        result = call_service
        order = result.data[:order]

        expect(order.items.count).to eq(1)
        expect(order.items.first.product).to eq(cart_item_to_order.product)

        expect(user.reload.cart_items.count).to eq(1)
        expect(user.cart_items.first).to eq(cart_item_to_keep)
      end
    end

    context 'when order creation fails due to a validation error' do
      let!(:cart_item) { create(:cart_item, user: user, product: product) }

      before do
        order = build(:order, user: user)
        allow(user.orders).to receive(:build).and_return(order)
        allow(order).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(order))
      end

      it 'does not create an order and leaves items in the cart' do
        expect { call_service }.not_to change(Order, :count)
        expect(user.reload.cart_items.count).to eq(1)
      end

      it 'returns a failure result with validation errors' do
        result = call_service

        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
        expect(result.message).to include('Validation failed')
      end
    end

    context 'when an unexpected standard error occurs' do
      let!(:cart_item) { create(:cart_item, user: user, product: product) }
      let(:error_message) { 'Database connection lost' }

      before do
        order = build(:order, user: user)
        allow(user.orders).to receive(:build).and_return(order)
        allow(order).to receive(:save!).and_raise(StandardError, error_message)
        allow(Rails.logger).to receive(:error)
      end

      it 'does not create an order and rolls back the transaction' do
        expect { call_service }.not_to change(Order, :count)
        expect(user.reload.cart_items.count).to eq(1)
      end

      it 'logs the error' do
        call_service
        expect(Rails.logger).to have_received(:error).with('An unexpected error occurred: Database connection lost')
      end

      it 'returns an internal server error result' do
        result = call_service
        expect(result.success?).to be false
        expect(result.status).to eq(:internal_server_error)
        expect(result.errors.first).to eq('Unknown error has occured during the operation')
      end
    end
  end
end
