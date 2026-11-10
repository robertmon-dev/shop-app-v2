# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::OrdersController, type: :controller do
  render_views

  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
  end

  let!(:user) { create(:user, :with_detail, role: :regular) }
  let!(:admin) { create(:user, :with_detail, role: :admin) }
  let!(:order) { create(:order, user: user) }
  let(:product) { create(:product) }
  let(:order_creation_service) { instance_double(Orders::Creation) }
  let(:order_management_service) { instance_double(Orders::Management) }

  before do
    controller.instance_variable_set(:@order, order)

    allow(Orders::Creation).to receive(:call).and_return(
      ApplicationService::Result.new(success?: true, data: { order: order }, status: :created,
                           message: 'Order created successfully.')
    )

    allow(Orders::Management).to receive(:new).with(order).and_return(order_management_service)

    allow(order_management_service).to receive(:add_product).and_return(
      ApplicationService::Result.new(success?: true, data: { order: order }, status: :ok, message: 'Product added successfully.')
    )
    allow(order_management_service).to receive(:remove_product).and_return(
      ApplicationService::Result.new(success?: true, data: { order: order }, status: :ok,
                           message: 'Product removed successfully.')
    )
    allow(order_management_service).to receive(:destroy).and_return(
      ApplicationService::Result.new(success?: true, status: :no_content)
    )
    allow(order_management_service).to receive(:update).and_return(
      ApplicationService::Result.new(success?: true, data: { order: order }, status: :ok,
                           message: 'Order updated successfully.')
    )
    allow(order_management_service).to receive(:cancel).and_return(
      ApplicationService::Result.new(success?: true, data: { order: order }, status: :ok,
                           message: 'Order cancelled successfully.')
    )
  end

  describe 'GET #index' do
    context 'as an admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin)
        allow(Order).to receive(:accessible_by).and_return(Order.all)
      end

      it 'returns a list of all orders' do
        get :index, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['orders'].count).to eq(Order.count)
      end
    end

    context 'as a regular user' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
        allow(Order).to receive(:accessible_by).and_return(user.orders)
      end

      it "returns a list of the user's own orders" do
        get :index, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['orders'].count).to eq(user.orders.count)
      end
    end
  end

  describe 'GET #me' do
    before do
      allow(controller).to receive(:current_user).and_return(user)
    end
    it "returns a list of the current user's orders" do
      get :me, format: :json
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['data']['orders'].first['id']).to eq(order.id)
    end
  end

  describe 'GET #show' do
    it 'returns a single order' do
      allow(controller).to receive(:current_user).and_return(user)
      get :show, params: { id: order.id }, format: :json
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['data']['order']['id']).to eq(order.id)
    end
  end

  describe 'POST #create' do
    let(:service_result) { ApplicationService::Result.new(success?: true, data: { order: order }, status: :created, message: 'Order created successfully from cart.') }
    before do
      allow(controller).to receive(:current_user).and_return(user)
      allow(Orders::Creation).to receive(:call).and_return(service_result)
    end
    it 'creates an order from the cart and returns success' do
      post :create, format: :json
      expect(response).to have_http_status(:created)
      json_response = JSON.parse(response.body)
      expect(json_response['message']).to eq('Order created successfully from cart.')
      expect(json_response['data']['order']['id']).to eq(order.id)
    end
  end

  describe 'PUT #update' do
    let(:valid_params) { { order: { status: 'shipped' } } }
    context 'when the update is successful' do
      it 'updates the order and returns success' do
        allow(controller).to receive(:current_user).and_return(admin)
        put :update, params: { id: order.id }.merge(valid_params), format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Order updated successfully.')
      end
    end
  end

  describe 'POST #cancel' do
    it 'cancels the order and returns success' do
      allow(controller).to receive(:current_user).and_return(user)
      post :cancel, params: { id: order.id }, format: :json
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['message']).to eq('Order cancelled successfully.')
    end
  end

  describe 'POST #add_product' do
    let(:params) { { id: order.id, order: { product_id: product.id, quantity: '2' } } }

    before do
      allow(controller).to receive(:current_user).and_return(admin)
    end

    context 'when the product exists' do
      before do
        allow(Product).to receive(:find_by).with(id: product.id.to_s).and_return(product)
      end

      it 'calls the order management service and returns a successful response' do
        expect(order_management_service).to receive(:add_product).with(product, 2)
        post :add_product, params: params, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Product added successfully.')
      end
    end

    context 'when the product does not exist' do
      before do
        allow(Product).to receive(:find_by).with(id: 'invalid-id').and_return(nil)
      end

      it 'returns a not found error' do
        params[:order][:product_id] = 'invalid-id'
        post :add_product, params: params, format: :json

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Product not found.')
      end
    end
  end

  describe 'DELETE #remove_product' do
    let(:params) { { id: order.id, product_id: product.id, quantity: '1' } }

    before do
      allow(controller).to receive(:current_user).and_return(admin)
    end

    context 'when the product exists' do
      before do
        allow(Product).to receive(:find_by).with(id: product.id.to_s).and_return(product)
      end
      it 'calls the order management service and returns a successful response' do
        expect(order_management_service).to receive(:remove_product).with(product, '1')
        delete :remove_product, params: params, format: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Product removed successfully.')
      end
    end

    context 'when the product does not exist' do
      before do
        allow(Product).to receive(:find_by).with(id: 'invalid-id').and_return(nil)
      end
      it 'returns a not found error' do
        params[:product_id] = 'invalid-id'
        delete :remove_product, params: params, format: :json

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Product not found.')
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the order and returns no content' do
      allow(controller).to receive(:current_user).and_return(admin)
      delete :destroy, params: { id: order.id }, format: :json
      expect(response).to have_http_status(:no_content)
    end
  end
end
