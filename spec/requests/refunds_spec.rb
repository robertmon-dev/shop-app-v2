# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Refunds', type: :request do
  let(:json) { JSON.parse(response.body) }

  let(:admin) { create(:user, :admin, :with_detail) }
  let(:user) { create(:user, :regular, :with_detail) }
  let(:other_user) { create(:user, :regular, :with_detail) }

  let!(:user_order) { create(:order, user: user, status: :delivered, payment_status: :paid) }

  def headers_for(actor)
    {
      'Authorization' => "Bearer #{Services::BearerService.encode({ user_id: actor.id }).data[:token]}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  describe 'POST /api/v1/orders/:order_id/refunds' do
    let(:params) { { refund: { reason: 'damaged', description: 'Arrived broken' } }.to_json }

    it 'creates a refund for the order owner' do
      created = Services::Result.new(success?: true, status: :created,
                                     data: { refund: build(:refund, order: user_order, user: user) },
                                     message: 'Refund requested')
      allow(Services::RefundCreationService).to receive(:call).and_return(created)

      post "/api/v1/orders/#{user_order.id}/refunds", params: params, headers: headers_for(user)

      expect(response).to have_http_status(:created)
    end

    it 'rejects an unauthenticated request' do
      post "/api/v1/orders/#{user_order.id}/refunds", params: params

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/refunds/me' do
    let!(:user_refund) { create(:refund, order: user_order, user: user) }

    it "returns the caller's refunds" do
      get '/api/v1/refunds/me', headers: headers_for(user)

      expect(response).to have_http_status(:ok)
      expect(json['refunds'].map { |refund| refund['id'] }).to contain_exactly(user_refund.id)
    end
  end

  describe 'GET /api/v1/refunds/:id' do
    let!(:user_refund) { create(:refund, order: user_order, user: user) }

    it 'returns the refund to its owner' do
      get "/api/v1/refunds/#{user_refund.id}", headers: headers_for(user)

      expect(response).to have_http_status(:ok)
      expect(json['refund']['id']).to eq(user_refund.id)
    end

    it "forbids reading another user's refund" do
      get "/api/v1/refunds/#{user_refund.id}", headers: headers_for(other_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/v1/refunds/:id/cancel' do
    let!(:user_refund) { create(:refund, order: user_order, user: user) }

    it 'cancels the refund for its owner' do
      cancelled = Services::Result.new(success?: true, status: :ok, data: { refund: user_refund },
                                       message: 'Refund cancelled')
      allow_any_instance_of(Services::RefundManagementService).to receive(:cancel).and_return(cancelled)

      post "/api/v1/refunds/#{user_refund.id}/cancel", headers: headers_for(user)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'DELETE /api/v1/refunds/:id' do
    let!(:user_refund) { create(:refund, order: user_order, user: user) }

    it 'deletes the refund as an admin' do
      destroyed = Services::Result.new(success?: true, status: :no_content, message: 'Refund deleted')
      allow(Services::RefundDeletionService).to receive(:call).and_return(destroyed)

      delete "/api/v1/refunds/#{user_refund.id}", headers: headers_for(admin)

      expect(response).to have_http_status(:no_content)
    end

    it 'forbids a regular user from deleting' do
      delete "/api/v1/refunds/#{user_refund.id}", headers: headers_for(user)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
