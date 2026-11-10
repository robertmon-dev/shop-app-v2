# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::OrderManagementService, type: :service do
  before do
    allow_any_instance_of(CartObserver).to receive(:after_create)
    allow_any_instance_of(CartObserver).to receive(:after_update)
    allow_any_instance_of(CartObserver).to receive(:after_destroy)

    allow_any_instance_of(OrderObserver).to receive(:after_create)
    allow_any_instance_of(OrderObserver).to receive(:after_destroy)
    allow_any_instance_of(OrderObserver).to receive(:after_update)
  end

  let!(:order) { create(:order, :with_items) }
  let(:service) { described_class.new(order) }

  describe '#update' do
    context 'with valid parameters' do
      it 'updates the order and returns a successful result' do
        result = service.update({ notes: 'Hell yeah' })

        expect(result.success?).to be true
        expect(order.reload.notes).to eq('Hell yeah')
        expect(result.status).to eq(:ok)
      end
    end

    context 'with invalid parameters' do
      it 'does not update the order and returns a failure result' do
        result = service.update({ status: nil })

        expect(result.success?).to be false
        expect(result.errors).to include("Status can't be blank")
        expect(result.status).to eq(:unprocessable_content)
      end
    end
  end

  describe '#cancel' do
    context 'when the order has a cancellable status (e.g., pending)' do
      it 'cancels the order successfully' do
        order.update!(status: :pending)
        result = service.cancel

        expect(result.success?).to be true
        expect(order.reload.status_cancelled?).to be true
      end
    end

    context 'when the order has a non-cancellable status (e.g., shipped)' do
      it 'returns a failure result and does not cancel the order' do
        order.update!(status: :shipped)
        result = service.cancel

        expect(result.success?).to be false
        expect(result.errors.first).to include('Cannot cancel order with status: shipped')
        expect(order.reload.status_shipped?).to be true
      end
    end
  end

  describe '#mark_as_paid' do
    it 'updates payment_status to paid' do
      service.mark_payment_status('paid')
      expect(order.reload.payment_status_paid?).to be true
    end
  end

  describe '#mark_as_shipped' do
    it 'updates status to shipped' do
      service.mark_order_status('shipped')
      expect(order.reload.status_shipped?).to be true
    end
  end

  describe '#add_product' do
    let(:new_product) { create(:product, price: 50) }

    context 'with valid input' do
      it 'adds a new product to the order' do
        new_product = create(:product, price: 50)
        result = service.add_product(new_product, 2)
        order.reload
        expect(result.success?).to be true

        expected_total = order.items.sum { |item| item.price_at_purchase * item.quantity }
        expect(order.total_amount).to be_within(0.01).of(expected_total)
      end

      it 'increases the quantity of an existing product' do
        existing_item = order.items.first
        initial_quantity = existing_item.quantity

        result = service.add_product(existing_item.product, 3)

        expect(result.success?).to be true
        expect(existing_item.reload.quantity).to eq(initial_quantity + 3)
      end
    end

    context 'with invalid input' do
      it 'returns a failure result for zero quantity' do
        result = service.add_product(new_product, 0)
        expect(result.success?).to be false
        expect(result.errors).to include('Invalid product or quantity.')
      end

      it 'returns a failure result for a nil product' do
        result = service.add_product(nil, 1)
        expect(result.success?).to be false
        expect(result.errors).to include('Invalid product or quantity.')
      end
    end

    context 'when an unexpected error occurs' do
      it 'logs the error and returns an internal_server_error result' do
        allow(order).to receive(:save!).and_raise(StandardError, 'DB error')
        allow(Rails.logger).to receive(:error)

        result = service.add_product(new_product, 1)

        expect(result.success?).to be false
        expect(result.status).to eq(:internal_server_error)
        expect(Rails.logger).to have_received(:error)
      end
    end
  end

  describe '#remove_product' do
    let!(:item_to_remove) { order.items.first }
    let!(:product_to_remove) { item_to_remove.product }

    before do
      item_to_remove.update!(quantity: 5)
    end

    context 'with valid input' do
      it 'decrements the quantity of an existing product' do
        result = service.remove_product(product_to_remove, 2)

        expect(result.success?).to be true
        expect(item_to_remove.reload.quantity).to eq(3)
      end

      it 'removes the item completely if the removed quantity is equal to the current quantity' do
        expect do
          service.remove_product(product_to_remove, 5)
        end.to change(order.items, :count).by(-1)
      end

      it 'removes the item completely when no quantity is specified' do
        expect do
          service.remove_product(product_to_remove)
        end.to change(order.items, :count).by(-1)
      end

      it 'updates the order total amount after removing an item' do
        initial_total = order.total_amount
        item_price = item_to_remove.price_at_purchase
        service.remove_product(product_to_remove, 2)
        expected_total = initial_total - (item_price * 2)

        expect(order.reload.total_amount).to be_within(0.01).of(expected_total)
      end
    end

    context 'with invalid input' do
      it 'returns a failure result when the product is not in the order' do
        other_product = create(:product)
        result = service.remove_product(other_product, 1)

        expect(result.success?).to be false
        expect(result.status).to eq(:not_found)
        expect(result.errors).to include('Product not found in order.')
      end

      it 'returns a failure result for a zero quantity' do
        result = service.remove_product(product_to_remove, 0)

        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
        expect(result.errors).to include('Quantity must be a positive number.')
      end

      it 'returns a failure result when trying to remove more items than available' do
        result = service.remove_product(product_to_remove, 10)

        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
        expect(result.errors).to include('Cannot remove 10 items, only 5 present.')
      end
    end
  end
end
