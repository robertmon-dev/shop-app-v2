# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Orders', type: :request do
  let(:json) { JSON.parse(response.body) }

  let(:admin) { create(:user, :admin, :with_detail) }
  let(:user) { create(:user, :regular, :with_detail) }
  let(:other_user) { create(:user, :with_detail) }
  let(:admin_headers) do
    {
      'Authorization' => "Bearer #{token_for(admin)}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end
  let(:user_headers) do
    {
      'Authorization' => "Bearer #{token_for(user)}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end
  let!(:product) { create(:product) }
  let!(:user_order) { create(:order, user: user) }
  let!(:other_user_order) { create(:order, user: other_user) }

  let(:order_management_service) { instance_double(Services::OrderManagementService) }

  def token_for(user)
    Services::BearerService.encode({ user_id: user.id }).data[:token]
  end

  shared_context 'with order management service mock' do
    before do
      allow(Services::OrderManagementService).to receive(:new).and_return(order_management_service)
    end
  end

  describe 'GET /api/v1/orders' do
    context 'as an admin' do
      it 'returns all orders' do
        get '/api/v1/orders', headers: admin_headers
        expect(response).to have_http_status(:ok)
        expect(json['orders'].size).to eq(Order.count)
      end
    end

    context 'as a regular user' do
      it "returns only the user's own orders" do
        get '/api/v1/orders', headers: user_headers
        expect(response).to have_http_status(:ok)
        expect(json['orders'].size).to eq(user.orders.count)
        expect(json['orders'].first['id']).to eq(user_order.id)
      end
    end
  end

  describe 'GET /api/v1/orders/me' do
    it "returns the current user's orders" do
      get '/api/v1/orders/me', headers: user_headers
      expect(response).to have_http_status(:ok)
      expect(json['orders'].first['id']).to eq(user_order.id)
    end
  end

  describe 'GET /api/v1/orders/:id' do
    it 'allows a user to see their own order' do
      get "/api/v1/orders/#{user_order.id}", headers: user_headers
      expect(response).to have_http_status(:ok)
      expect(json['order']['id']).to eq(user_order.id)
    end
  end

  describe 'POST /api/v1/orders' do
    context 'when creation is successful' do
      let(:success_result) { Services::Result.new(success?: true, data: { order: user_order }, status: :created) }
      before { allow(Services::OrderCreationService).to receive(:call).and_return(success_result) }

      it 'returns a 201 status and the order' do
        post '/api/v1/orders', headers: user_headers, params: {}.to_json
        expect(response).to have_http_status(:created)
        expect(json['order']['id']).to eq(user_order.id)
      end
    end

    context 'when creation fails' do
      # Poprawka warningu: :unprocessable_entity -> :unprocessable_content
      let(:failure_result) { Services::Result.new(success?: false, errors: ['Cart is empty'], status: :unprocessable_content) }
      before { allow(Services::OrderCreationService).to receive(:call).and_return(failure_result) }

      it 'returns a 422 status with errors' do
        post '/api/v1/orders', headers: user_headers, params: {}.to_json
        expect(response).to have_http_status(:unprocessable_content)
        expect(json['errors']).to include('Cart is empty')
      end
    end
  end

  describe 'PATCH /api/v1/orders/:id' do
    include_context 'with order management service mock'
    let(:update_params) { { order: { status: 'shipped' } }.to_json }

    context 'as an admin' do
      it 'updates the order' do
        allow(order_management_service).to receive(:update).and_return(Services::Result.new(success?: true,
                                                                                            data: { order: user_order }, status: :ok))
        patch "/api/v1/orders/#{user_order.id}", headers: admin_headers, params: update_params
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as a regular user' do
      it 'is forbidden' do
        patch "/api/v1/orders/#{user_order.id}", headers: user_headers, params: update_params
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/v1/orders/:id/products' do
    include_context 'with order management service mock'
    let(:add_product_params) { { order: { product_id: product.id, quantity: 2 } }.to_json }

    it 'adds a product to an order' do
      allow(order_management_service).to receive(:add_product).with(product,
                                                                    2).and_return(Services::Result.new(success?: true,
                                                                                                       data: { order: user_order }, status: :ok))
      post "/api/v1/orders/#{user_order.id}/products", headers: admin_headers, params: add_product_params
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /api/v1/orders/:id/cancel' do
    include_context 'with order management service mock'

    it 'allows a user to cancel their own order' do
      allow(order_management_service).to receive(:cancel).and_return(Services::Result.new(success?: true,
                                                                                          data: { order: user_order }, status: :ok))
      post "/api/v1/orders/#{user_order.id}/cancel", headers: user_headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'DELETE /api/v1/orders/:id' do
    include_context 'with order management service mock'

    context 'as an admin' do
      it 'deletes the order' do
        allow(order_management_service).to receive(:destroy).and_return(Services::Result.new(success?: true,
                                                                                             status: :no_content))
        delete "/api/v1/orders/#{user_order.id}", headers: admin_headers
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'as a regular user' do
      it 'is forbidden' do
        delete "/api/v1/orders/#{user_order.id}", headers: user_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH /api/v1/orders/:id/status' do
    it 'marks the order status as an admin' do
      patch "/api/v1/orders/#{user_order.id}/status",
            params: { order: { status: 'shipped' } }.to_json, headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(user_order.reload.status_shipped?).to be true
    end

    it 'is forbidden for a regular user' do
      patch "/api/v1/orders/#{user_order.id}/status",
            params: { order: { status: 'shipped' } }.to_json, headers: user_headers

      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects an unknown status' do
      patch "/api/v1/orders/#{user_order.id}/status",
            params: { order: { status: 'teleported' } }.to_json, headers: admin_headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH /api/v1/orders/:id/payment_status' do
    it 'marks the payment status as an admin' do
      patch "/api/v1/orders/#{user_order.id}/payment_status",
            params: { order: { payment_status: 'paid' } }.to_json, headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(user_order.reload.payment_status_paid?).to be true
    end
  end
end
