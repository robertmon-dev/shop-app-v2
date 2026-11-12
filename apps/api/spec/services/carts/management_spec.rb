# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Carts::Management, type: :service do
  let(:user) { create(:user) }
  let(:product) { create(:product, price: 19.99) }
  let(:service) { described_class.new(user) }

  before do
    allow(Rails.logger).to receive(:error)
  end

  describe '#add_product' do
    context 'with valid data' do
      it 'adds a new product to the cart' do
        expect(user.cart_items.find_by(product: product)).to be_nil

        result = service.add(product.id, 2)

        expect(result.success?).to be true
        expect(user.cart_items.count).to eq(1)
        expect(user.cart_items.first.quantity).to eq(2)
      end

      it 'increments the quantity of an existing product in the cart' do
        create(:cart_item, user: user, product: product, quantity: 1)

        result = service.add(product.id, 3)

        expect(result.success?).to be true
        expect(user.cart_items.count).to eq(1)
        expect(user.cart_items.first.quantity).to eq(4)
      end
    end

    context 'with invalid data' do
      it 'returns a not_found error for a non-existent product' do
        result = service.add('non-existent-id', 1)
        expect(result.success?).to be false
        expect(result.status).to eq(:not_found)
      end

      it 'returns an unprocessable_content error for zero or negative quantity' do
        result_zero = service.add(product.id, 0)
        result_negative = service.add(product.id, -5)

        expect(result_zero.success?).to be false
        expect(result_zero.status).to eq(:unprocessable_content)
        expect(result_negative.success?).to be false
        expect(result_negative.status).to eq(:unprocessable_content)
      end
    end

    context 'when saving fails' do
      it 'returns an error on validation failure' do
        invalid_item = build(:cart_item, user: user, product: product, quantity: 0)
        expect(invalid_item).not_to be_valid
        exception = ActiveRecord::RecordInvalid.new(invalid_item)
        allow_any_instance_of(Item).to receive(:save!).and_raise(exception)

        result = service.add(product.id, 1)

        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
        expect(result.errors).to include('Quantity must be greater than 0')
      end
    end
  end

  describe '#remove_product' do
    let!(:cart_item) { create(:cart_item, user: user, product: product, quantity: 5) }

    it 'decrements the quantity of a product' do
      result = service.remove(cart_item.id, 2)
      expect(result.success?).to be true
      expect(cart_item.reload.quantity).to eq(3)
    end

    it 'removes the item completely if quantity to remove is greater than current' do
      expect { service.remove(cart_item.id, 6) }.to change(Item, :count).by(-1)
    end

    it 'removes the item completely if quantity to remove equals current' do
      expect { service.remove(cart_item.id, 5) }.to change(Item, :count).by(-1)
    end

    it 'removes the item completely if quantity is not provided (nil)' do
      expect { service.remove(cart_item.id) }.to change(Item, :count).by(-1)
    end

    it 'returns a not_found status for a non-existent cart item' do
      result = service.remove('non-existent-id')
      expect(result.success?).to be false
      expect(result.status).to eq(:not_found)
    end
  end

  describe '#clear' do
    it 'removes all items from the cart' do
      create_list(:cart_item, 3, user: user)
      expect(user.cart_items.count).to eq(3)

      result = service.clear
      expect(result.success?).to be true
      expect(user.cart_items.count).to eq(0)
    end
  end

  describe '#get_cart_summary' do
    context 'when the cart is empty' do
      it 'returns zero totals' do
        summary = service.cart_summary
        expect(summary[:cart_items]).to be_empty
        expect(summary[:total_amount]).to eq(0)
        expect(summary[:items_count]).to eq(0)
      end
    end

    context 'when the cart has items' do
      it 'returns correct totals and items' do
        product2 = create(:product, price: 10.00)
        create(:cart_item, user: user, product: product, quantity: 2, price_at_purchase: 20.00)
        create(:cart_item, user: user, product: product2, quantity: 3, price_at_purchase: 10.00)

        summary = service.cart_summary

        expect(summary[:cart_items].size).to eq(2)
        expect(summary[:items_count]).to eq(5)
        expect(summary[:total_amount]).to eq(69.98)
      end

      it 'prices the cart at what the products cost now' do
        create(:cart_item, user: user, product: product, quantity: 2, price_at_purchase: 1.00)
        product.update!(price: 20.00)

        expect(service.cart_summary[:total_amount]).to eq(40.00)
      end
    end
  end
end
