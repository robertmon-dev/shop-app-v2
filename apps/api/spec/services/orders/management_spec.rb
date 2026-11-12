# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Management, type: :service do
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

  describe '#destroy' do
    it 'refunds a paid order before destroying it' do
      allow(Stripe::Refund).to receive(:create).and_return(double(id: 're_1'))
      order.update!(status: :pending, payment_status: :paid)
      create(:payment, :paid, order: order)

      result = service.destroy

      expect(result.success?).to be true
      expect(Stripe::Refund).to have_received(:create)
      expect(Order.exists?(order.id)).to be false
    end

    it 'keeps the order when the refund fails' do
      allow(Stripe::Refund).to receive(:create).and_raise(Stripe::APIConnectionError.new('down'))
      order.update!(status: :pending, payment_status: :paid)
      create(:payment, :paid, order: order)

      expect(service.destroy.success?).to be false
      expect(Order.exists?(order.id)).to be true
    end
  end

  describe '#mark_payment_status' do
    %w[paid refunded].each do |current|
      it "refuses to change a #{current} order by hand" do
        order.update!(payment_status: current)

        expect(service.mark_payment_status('unpaid').success?).to be false
        expect(order.reload.payment_status).to eq(current)
      end
    end

    it 'allows marking a payment as failed' do
      result = service.mark_payment_status('failed')

      expect(result.success?).to be true
      expect(order.reload.payment_status_failed?).to be true
    end

    %w[paid refunded].each do |status|
      it "refuses to set #{status} by hand" do
        result = service.mark_payment_status(status)

        expect(result.success?).to be false
        expect(order.reload.payment_status_unpaid?).to be true
      end
    end
  end

  describe '#mark_order_status' do
    it 'follows the status graph' do
      expect(service.mark_order_status('processing').success?).to be true
      expect(service.mark_order_status('shipped').success?).to be true
      expect(order.reload.status_shipped?).to be true
    end

    it 'refuses to cancel without going through the cancel action' do
      result = service.mark_order_status('cancelled')

      expect(result.success?).to be false
      expect(order.reload.status_pending?).to be true
    end

    it 'refuses to skip steps' do
      result = service.mark_order_status('delivered')

      expect(result.success?).to be false
      expect(order.reload.status_pending?).to be true
    end

    it 'refuses to leave a final status' do
      order.update!(status: :cancelled)

      expect(service.mark_order_status('processing').success?).to be false
    end

    it 'refuses to mark an order refunded without a refund' do
      order.update!(status: :delivered)

      expect(service.mark_order_status('refunded').success?).to be false
    end
  end

  describe '#update with status fields' do
    it 'applies the same rules as the dedicated endpoints' do
      expect(service.update({ payment_status: 'paid' }).success?).to be false
      expect(service.update({ status: 'delivered' }).success?).to be false
      expect(order.reload).to have_attributes(status: 'pending', payment_status: 'unpaid')
    end
  end

  describe '#cancel and payments' do
    before do
      allow(Stripe::Refund).to receive(:create).and_return(double(id: 're_1'))
      allow(Stripe::PaymentIntent).to receive(:cancel)
    end

    context 'when the order is paid' do
      let!(:order) { create(:order, :with_items, payment_status: :paid) }
      let!(:payment) { create(:payment, :paid, order: order) }

      it 'refunds the payment in Stripe and records it' do
        result = service.cancel

        expect(result.success?).to be true
        expect(Stripe::Refund).to have_received(:create).with(
          { payment_intent: payment.stripe_payment_intent_id, metadata: { order_id: order.id } },
          { idempotency_key: "order-cancel-#{order.id}" }
        )
        expect(order.reload).to have_attributes(status: 'cancelled', payment_status: 'refunded')
        expect(payment.reload.status).to eq('refunded')
      end

      it 'keeps the order untouched when Stripe fails' do
        allow(Stripe::Refund).to receive(:create).and_raise(Stripe::APIConnectionError.new('down'))

        result = service.cancel

        expect(result.success?).to be false
        expect(order.reload).to have_attributes(status: 'pending', payment_status: 'paid')
        expect(payment.reload.status).to eq('paid')
      end
    end

    context 'when the order is unpaid but has a PaymentIntent' do
      before { order.update!(stripe_payment_intent_id: 'pi_open') }

      it 'cancels the PaymentIntent so it can no longer be paid' do
        result = service.cancel

        expect(result.success?).to be true
        expect(Stripe::PaymentIntent).to have_received(:cancel).with('pi_open')
        expect(Stripe::Refund).not_to have_received(:create)
      end
    end

    context 'when the order has no PaymentIntent' do
      it 'does not call Stripe' do
        service.cancel

        expect(Stripe::PaymentIntent).not_to have_received(:cancel)
        expect(Stripe::Refund).not_to have_received(:create)
      end
    end
  end

  describe 'stock' do
    let(:product) { create(:product, price: 50, stock_quantity: 5) }
    let!(:item) { create(:item, order: order, product: product, quantity: 2, price_at_purchase: 50) }

    it 'takes stock when a product is added' do
      result = service.add_product(product, 3)

      expect(result.success?).to be true
      expect(product.reload.stock_quantity).to eq(2)
    end

    it 'refuses to add more than is in stock' do
      result = service.add_product(product, 6)

      expect(result.success?).to be false
      expect(result.errors.first).to include('Not enough stock')
      expect(product.reload.stock_quantity).to eq(5)
    end

    it 'gives stock back when a product is removed' do
      service.remove_product(product)

      expect(product.reload.stock_quantity).to eq(7)
    end

    it 'gives back only the removed part when the quantity is decreased' do
      service.remove_product(product, 1)

      expect(product.reload.stock_quantity).to eq(6)
      expect(item.reload.quantity).to eq(1)
    end

    it 'gives stock back when the order is cancelled' do
      service.cancel

      expect(product.reload.stock_quantity).to eq(7)
    end

    it 'gives stock back when a pending order is destroyed' do
      service.destroy

      expect(product.reload.stock_quantity).to eq(7)
    end

    it 'does not give stock back for an order that was already delivered' do
      order.update!(status: :delivered)
      service.destroy

      expect(product.reload.stock_quantity).to eq(5)
    end
  end

  describe 'modifying a paid order' do
    let(:product) { create(:product) }

    before { order.update!(payment_status: :paid) }

    it 'refuses to add a product' do
      expect(service.add_product(product, 1).success?).to be false
    end

    it 'refuses to remove a product' do
      expect(service.remove_product(order.items.first.product).success?).to be false
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
