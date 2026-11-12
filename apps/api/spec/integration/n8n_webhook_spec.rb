# frozen_string_literal: true

require 'swagger_helper'

describe 'n8n webhook API' do
  let(:secret) { ENV.fetch('N8N_WEBHOOK_SECRET') }
  let!(:order) { create(:order, status: :processing, payment_status: :paid, user: create(:user, :with_full_details)) }

  path '/api/v1/n8n_webhook/handle' do
    post 'Receives shipment events from n8n' do
      tags 'Webhooks'
      consumes 'application/json'
      produces 'application/json'
      parameter name: 'X-N8N-Signature', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { event: { type: :string }, order_id: { type: :integer }, tracking_id: { type: :string },
                      shipping_service_id: { type: :string }, notes: { type: :string } },
        required: %w[event order_id]
      }
      let('X-N8N-Signature') { secret }
      let(:body) { { event: 'shipment.shipped', order_id: order.id, tracking_id: 'TRACK1' } }

      response '200', 'order updated' do
        schema envelope_schema(order_id: { type: :integer })
        run_test!
      end

      response '401', 'invalid signature' do
        let('X-N8N-Signature') { 'wrong' }
        schema failure_schema
        run_test!
      end

      response '422', 'unsupported event' do
        let(:body) { { event: 'shipment.unknown', order_id: order.id } }
        schema failure_schema
        run_test!
      end
    end
  end
end
