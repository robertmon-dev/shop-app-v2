# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Carts::SummaryCache do
  let(:store) { ActiveSupport::Cache::MemoryStore.new }
  let!(:user) { create(:user, :with_detail) }
  let!(:other_user) { create(:user, :with_detail) }
  let(:product) { create(:product, price: 10.00, stock_quantity: nil) }
  let(:service) { Carts::Management.new(user) }

  before { allow(Rails).to receive(:cache).and_return(store) }

  def total(for_user = user) = Carts::Management.new(for_user).cart_summary[:total_amount]

  it 'serves the second read from the cache' do
    create(:cart_item, user: user, product: product, quantity: 1)
    service.cart_summary

    expect(user).not_to receive(:cart_items)
    expect(service.cart_summary[:items_count]).to eq(1)
  end

  it 'keeps one entry per user' do
    create(:cart_item, user: user, product: product, quantity: 1)
    create(:cart_item, user: other_user, product: product, quantity: 4)

    expect(total(user)).to eq(10)
    expect(total(other_user)).to eq(40)
  end

  describe 'invalidation' do
    let!(:cart_item) { create(:cart_item, user: user, product: product, quantity: 1) }

    before { total }

    it 'when an item is added through the cart' do
      service.add(product.id, 2)

      expect(total).to eq(30)
    end

    it 'when an item is removed' do
      service.remove(cart_item.id)

      expect(total).to eq(0)
    end

    it 'when the cart is cleared' do
      service.clear

      expect(service.cart_summary[:items_count]).to eq(0)
    end

    it 'when the price of a product in the cart changes' do
      product.update!(price: 25.00)

      expect(total).to eq(25)
    end

    it 'when the name of a product in the cart changes' do
      product.update!(name: 'Renamed')

      expect(service.cart_summary[:cart_items].first[:product][:name]).to eq('Renamed')
    end

    it 'without touching other users when a product they do not have changes' do
      create(:cart_item, user: other_user, product: create(:product, price: 3.00), quantity: 1)
      total(other_user)

      expect(store).not_to receive(:delete).with(a_string_including("carts/#{other_user.id}/"))
      product.update!(price: 99.00)
    end

    it 'does not invalidate anything when an unrelated product attribute changes' do
      expect(Carts::SummaryCache).not_to receive(:expire_for_product)

      product.update!(description: 'New description')
    end

    it 'when the cart is turned into an order' do
      location = user.user_detail.locations.create!(attributes_for(:location))
      Orders::Creation.call(user: user, package_carrier: :inpost, location_id: location.id)

      expect(service.cart_summary[:items_count]).to eq(0)
    end
  end
end
