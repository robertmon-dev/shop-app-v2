# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Payments', type: :request do
  let(:json) { JSON.parse(response.body) }

  let(:admin) { create(:user, :admin, :with_detail) }
  let(:user) { create(:user, :with_detail, :regular) }
  let(:other_user) { create(:user, :with_detail, :regular) }
  let!(:user_order) { create(:order, user: user) }
  let!(:other_user_order) { create(:order, user: other_user) }
  let!(:user_payment) { create(:payment, order: user_order) }
  let!(:other_user_payment) { create(:payment, order: other_user_order) }
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

  def token_for(user)
    Auth::Bearer.encode({ user_id: user.id }).data[:token]
  end

  describe 'GET /api/v1/payments' do
    context 'as an admin' do
      it 'returns all payments' do
        get '/api/v1/payments', headers: admin_headers
        expect(response).to have_http_status(:ok)
        expect(json['data']['payments'].size).to eq(Payment.count)
      end
    end

    context 'as a regular user' do
      it 'is forbidden' do
        get '/api/v1/payments', headers: user_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get '/api/v1/payments'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/payments/:id' do
    context 'as an admin' do
      it "can view another user's payment" do
        get "/api/v1/payments/#{user_payment.id}", headers: admin_headers
        expect(response).to have_http_status(:ok)
        expect(json['data']['payment']['id']).to eq(user_payment.id)
      end
    end

    context 'as the owning user' do
      it 'can view their own payment' do
        get "/api/v1/payments/#{user_payment.id}", headers: user_headers
        expect(response).to have_http_status(:ok)
        expect(json['data']['payment']['id']).to eq(user_payment.id)
      end
    end

    context 'as a non-owning user' do
      it "is forbidden from viewing another user's payment" do
        get "/api/v1/payments/#{other_user_payment.id}", headers: user_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        get "/api/v1/payments/#{user_payment.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/payments' do
    let(:valid_params) { { payment: { order_id: user_order.id, stripe_token: 'tok_visa' } }.to_json }

    context 'when creation is successful' do
      before do
        successful_result = ApplicationService::Result.new(success?: true, data: { client_secret: 'pi_secret_123' },
                                                       status: :ok)
        allow(Payments::Creation).to receive(:call).and_return(successful_result)
      end

      it 'returns the client secret of the payment intent' do
        post '/api/v1/payments', headers: user_headers, params: valid_params
        expect(response).to have_http_status(:ok)
        expect(json['data']['client_secret']).to eq('pi_secret_123')
      end
    end

    context 'when creation fails due to a processing error' do
      before do
        failed_result = ApplicationService::Result.new(success?: false, errors: ['Your card was declined.'],
                                             status: :unprocessable_content)
        allow(Payments::Creation).to receive(:call).and_return(failed_result)
      end

      it 'returns a 422 status with errors' do
        post '/api/v1/payments', headers: user_headers, params: valid_params
        expect(response).to have_http_status(:unprocessable_content)
        expect(json['errors']).to include('Your card was declined.')
      end
    end

    context 'when a user tries to pay for an order they do not own' do
      let(:unauthorized_params) { { payment: { order_id: other_user_order.id, stripe_token: 'tok_visa' } }.to_json }
      before do
        forbidden_result = ApplicationService::Result.new(success?: false,
                                                errors: ['You are not authorized to pay for this order.'], status: :forbidden)
        allow(Payments::Creation).to receive(:call)
          .with(hash_including(user: user, order_id: other_user_order.id))
          .and_return(forbidden_result)
      end

      it 'is forbidden' do
        post '/api/v1/payments', headers: user_headers, params: unauthorized_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized' do
        post '/api/v1/payments', params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
