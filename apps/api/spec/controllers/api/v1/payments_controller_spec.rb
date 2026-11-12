# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::PaymentsController, type: :controller do
  render_views

  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
  end

  let!(:user) { create(:user, :with_detail, role: :regular) }
  let!(:admin) { create(:user, :with_detail, role: :admin) }
  let!(:order) { create(:order, user: user) }
  let!(:payment) { create(:payment, order: order) }
  let(:payment_creation_service) { instance_double(Payments::Creation) }

  before do
    allow(Payments::Creation).to receive(:call).and_return(
      ApplicationService::Result.new(success?: true, data: { payment: payment }, status: :created,
                           message: 'Payment initiated successfully.')
    )
  end

  describe 'GET #index' do
    context 'as an admin' do
      before do
        allow(controller).to receive(:current_user).and_return(admin)
        allow(Payment).to receive(:accessible_by).and_return(Payment.all)
      end

      it 'returns a list of all payments' do
        get :index, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['payments'].count).to eq(Payment.count)
      end
    end

    context 'as a regular user' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
      end

      it 'lists only their own payments' do
        create(:payment, order: create(:order))

        get :index, format: :json

        expect(response).to have_http_status(:ok)
        ids = JSON.parse(response.body)['data']['payments'].map { |item| item['id'] }
        expect(ids).to eq([payment.id])
      end
    end
  end

  describe 'GET #show' do
    context 'as the owner of the payment' do
      before do
        allow(controller).to receive(:current_user).and_return(user)
      end

      it 'returns a single payment' do
        get :show, params: { id: payment.id }, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['data']['payment']['id']).to eq(payment.id)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) { { payment: { order_id: order.id, stripe_token: 'tok_visa' } } }
    let(:service_result) { ApplicationService::Result.new(success?: true, data: { client_secret: 'pi_secret_123' }, status: :ok,
                                                     message: 'Payment initiated successfully.') }

    before do
      allow(controller).to receive(:current_user).and_return(user)
      allow(Payments::Creation).to receive(:call).and_return(service_result)
    end

    it 'creates a new payment and returns success' do
      post :create, params: valid_params, format: :json
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['message']).to eq('Payment initiated successfully.')
      expect(json_response['data']['client_secret']).to eq('pi_secret_123')
    end
  end
end
