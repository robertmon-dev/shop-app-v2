# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::N8nWebhook', type: :request do
  let(:json) { JSON.parse(response.body) }
  let!(:order) { create(:order, status: :pending) }
  let(:secret) { ENV.fetch('N8N_WEBHOOK_SECRET') }

  def post_webhook(signature: secret, **payload)
    post '/api/v1/n8n_webhook/handle',
         params: payload.to_json,
         headers: { 'Content-Type' => 'application/json', 'X-N8N-Signature' => signature }.compact
  end

  describe 'POST /api/v1/n8n_webhook/handle' do
    it 'accepts a signed shipment event and advances the order' do
      post_webhook(event: 'shipment.shipped', order_id: order.id, tracking_id: 'TRK-9')

      expect(response).to have_http_status(:ok)
      expect(json['success']).to be true
      expect(order.reload.status_shipped?).to be true
      expect(order.transaction_id).to eq('TRK-9')
    end

    it 'rejects a request without a signature' do
      post_webhook(signature: nil, event: 'shipment.shipped', order_id: order.id)

      expect(response).to have_http_status(:unauthorized)
      expect(order.reload.status_pending?).to be true
    end

    it 'rejects a wrong signature' do
      post_webhook(signature: 'nope', event: 'shipment.shipped', order_id: order.id)

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns unprocessable_content for an unsupported event' do
      post_webhook(event: 'shipment.exploded', order_id: order.id)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns not found for an unknown order' do
      post_webhook(event: 'shipment.shipped', order_id: 0)

      expect(response).to have_http_status(:not_found)
    end

    it 'does not require authentication' do
      post_webhook(event: 'shipment.created', order_id: order.id)

      expect(response).to have_http_status(:ok)
    end
  end
end
