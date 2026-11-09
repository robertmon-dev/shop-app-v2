# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::CartController, type: :controller do
  render_views

  let!(:user) { create(:user, :with_detail) }
  let!(:product) { create(:product) }
  let!(:cart_item) { create(:item, :in_cart, user: user, product: product) }
  let(:cart_service_instance) { instance_double(Services::CartService) }
  let(:empty_cart_summary) { { cart_items: [], total_amount: 0.0, items_count: 0 } }
  let(:cart_summary_result) do
    items_relation = Item.where(id: cart_item.id).includes(:product)
    { cart_items: items_relation, total_amount: cart_item.price_at_purchase, items_count: 1 }
  end

  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
    allow(Services::CartService).to receive(:new).with(user).and_return(cart_service_instance)
  end

  describe 'GET #show' do
    it 'returns the current cart summary' do
      allow(cart_service_instance).to receive(:cart_summary).and_return(cart_summary_result)

      get :show, format: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.dig('data', 'items_count')).to eq(1)
      expect(json.dig('data', 'items').first['item_id']).to eq(cart_item.id)
    end
  end

  describe 'POST #add' do
    before do
      allow(cart_service_instance).to receive(:cart_summary).and_return(cart_summary_result)
    end

    context 'with valid parameters' do
      it 'adds a product and renders the updated cart' do
        result = instance_double(Services::Result, success?: true, status: :ok, message: 'Added.', errors: [], data: {})
        allow(cart_service_instance).to receive(:add).with(product.id.to_s, '1').and_return(result)

        post :add, params: { product_id: product.id, quantity: 1 }, format: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Added.')
      end
    end
  end

  describe 'DELETE #revoke' do
    before do
      allow(cart_service_instance).to receive(:cart_summary).and_return(cart_summary_result)
    end

    context 'with valid item_id' do
      it 'removes an item and renders the updated cart' do
        result = instance_double(Services::Result, success?: true, status: :ok, message: 'Removed.', errors: [],
                                                   data: {})
        allow(cart_service_instance).to receive(:remove).with(cart_item.id.to_s, '1').and_return(result)

        delete :revoke, params: { item_id: cart_item.id, quantity_to_remove: 1 }, format: :json

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'DELETE #clear' do
    it 'clears the cart and renders the empty cart summary' do
      result = instance_double(Services::Result, success?: true, status: :ok, message: 'Cleared.', errors: [], data: {})
      allow(cart_service_instance).to receive(:clear).and_return(result)
      allow(cart_service_instance).to receive(:cart_summary).and_return(empty_cart_summary)

      delete :clear, format: :json

      expect(response).to have_http_status(:ok)
    end
  end
end
