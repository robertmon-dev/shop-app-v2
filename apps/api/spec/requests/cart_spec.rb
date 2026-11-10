# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Carts', type: :request do
  let(:json) { JSON.parse(response.body) }
  let!(:user) { create(:user, :with_detail) }
  let!(:product) { create(:product, price: 100.0) }
  let(:auth_headers) do
    token_result = Auth::Bearer.encode({ user_id: user.id })
    { 'Authorization' => "Bearer #{token_result.data[:token]}" }
  end

  describe 'GET /api/v1/cart' do
    context 'when user is authenticated and cart is not empty' do
      let!(:cart_item) { create(:cart_item, user: user, product: product, quantity: 2) }

      before { get '/api/v1/cart', headers: auth_headers }

      it 'returns status ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the cart items within a data object' do
        expect(json['data']['items'].size).to eq(1)
        expect(json['data']['items'].first['item_id']).to eq(cart_item.id)
      end

      it 'returns correct cart summary' do
        expect(json['data']['items_count']).to eq(2)
        expect(json['data']['total_amount']).to eq('200.0')
      end
    end

    context 'when user is authenticated and cart is empty' do
      before { get '/api/v1/cart', headers: auth_headers }

      it 'returns an empty cart' do
        expect(response).to have_http_status(:ok)
        expect(json['data']['items']).to be_empty
        expect(json['data']['items_count']).to eq(0)
        expect(json['data']['total_amount']).to eq('0.0')
      end
    end
  end

  describe 'POST /api/v1/cart/add/:product_id' do
    context 'when adding a new product' do
      it 'adds the product to the cart and returns the updated cart' do
        expect do
          post "/api/v1/cart/add/#{product.id}", params: { quantity: 2 }, headers: auth_headers
        end.to change(user.cart_items, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(json['data']['items_count']).to eq(2)
      end
    end

    context 'when increasing quantity of an existing product' do
      let!(:cart_item) { create(:cart_item, user: user, product: product, quantity: 1) }

      it 'increases the quantity and returns the updated cart' do
        post "/api/v1/cart/add/#{product.id}", params: { quantity: 3 }, headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(cart_item.reload.quantity).to eq(4)
        expect(json['data']['items_count']).to eq(4)
      end
    end
  end

  describe 'DELETE /api/v1/cart/revoke/:item_id' do
    let!(:cart_item) { create(:cart_item, user: user, product: product, quantity: 5) }

    context 'when removing a specific quantity' do
      it 'decrements the item quantity' do
        delete "/api/v1/cart/revoke/#{cart_item.id}", params: { quantity_to_remove: 2 }, headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(cart_item.reload.quantity).to eq(3)
        expect(json['data']['items_count']).to eq(3)
      end
    end
  end

  describe 'DELETE /api/v1/cart/clear' do
    let!(:cart_item1) { create(:cart_item, user: user, product: product) }

    it 'removes all items from the cart' do
      delete '/api/v1/cart/clear', headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(user.reload.cart_items).to be_empty
      expect(json['data']['items']).to be_empty
    end
  end
end
