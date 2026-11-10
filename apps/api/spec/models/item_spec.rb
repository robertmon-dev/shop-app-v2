# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Item, type: :model do
  before do
    allow_any_instance_of(CartObserver).to receive(:after_create)
    allow_any_instance_of(CartObserver).to receive(:after_update)
    allow_any_instance_of(CartObserver).to receive(:after_destroy)
  end

  describe 'associations' do
    it { should belong_to(:product) }
    it { should belong_to(:order).optional }
    it { should belong_to(:user).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:quantity) }
    it { should validate_numericality_of(:quantity).is_greater_than(0) }

    it { should validate_presence_of(:price_at_purchase) }
    it { should validate_numericality_of(:price_at_purchase).is_greater_than_or_equal_to(0) }

    context 'custom validation: must_belong_to_user_or_order' do
      let(:product) { create(:product) }

      it 'is valid when belonging to an order' do
        item = build(:item, user: nil, order: create(:order), product: product)
        expect(item).to be_valid
      end

      it 'is valid when belonging to a user (cart)' do
        item = build(:item, :in_cart, order: nil, user: create(:user), product: product)
        expect(item).to be_valid
      end

      it 'is invalid when belonging to neither a user nor an order' do
        item = build(:item, user: nil, order: nil, product: product)
        expect(item).not_to be_valid
        expect(item.errors[:base]).to include('Item must belong to a user (for cart) or an order')
      end

      it 'is invalid when belonging to both a user and an order' do
        item = build(:item, user: create(:user), order: create(:order), product: product)
        expect(item).not_to be_valid
        expect(item.errors[:base]).to include('Item cannot belong to both a user (cart) and an order simultaneously')
      end
    end
  end

  describe 'callbacks' do
    let(:order) { create(:order) }
    let(:product) { create(:product, price: 100) }

    before do
      allow(order).to receive(:calculate_total_amount)
      allow(order).to receive(:save!)
    end

    it 'calls recalculate_order_total after create' do
      item = build(:item, order: order, product: product)
      expect(item).to receive(:recalculate_order_total).and_call_original
      item.save!
    end

    it 'calls recalculate_order_total after update' do
      item = create(:item, order: order, product: product)
      expect(item).to receive(:recalculate_order_total).and_call_original
      item.update!(quantity: 5)
    end

    it 'calls recalculate_order_total after destroy' do
      item = create(:item, order: order, product: product)
      expect(item).to receive(:recalculate_order_total).and_call_original
      item.destroy
    end

    it 'triggers calculate_total_amount and save! on the order when recalculate_order_total is called and order is present' do
      item = create(:item, order: order, product: product)

      RSpec::Mocks.space.proxy_for(order).reset

      allow(order).to receive(:calculate_total_amount)
      allow(order).to receive(:save!)

      item.send(:recalculate_order_total)

      expect(order).to have_received(:calculate_total_amount).once
      expect(order).to have_received(:save!).once
    end

    it 'does not trigger recalculation if order is nil' do
      item = create(:item, :in_cart, order: nil, user: create(:user), product: product)
      expect(item.order).to be_nil
      expect(order).not_to receive(:calculate_total_amount)
      expect(order).not_to receive(:save!)

      item.send(:recalculate_order_total)
    end
  end
end
