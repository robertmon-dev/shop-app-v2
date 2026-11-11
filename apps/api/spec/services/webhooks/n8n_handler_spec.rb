# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::N8nHandler, type: :service do
  let!(:order) { create(:order, status: :pending) }

  describe '.call' do
    it 'moves the order to processing on shipment.created' do
      result = described_class.call(event: 'shipment.created', order_id: order.id)

      expect(result.success?).to be true
      expect(order.reload.status_processing?).to be true
    end

    it 'moves the order to shipped on shipment.shipped' do
      described_class.call(event: 'shipment.shipped', order_id: order.id)

      expect(order.reload.status_shipped?).to be true
    end

    it 'moves the order to delivered on shipment.delivered' do
      described_class.call(event: 'shipment.delivered', order_id: order.id)

      expect(order.reload.status_delivered?).to be true
    end

    it 'stores the tracking id when provided' do
      described_class.call(event: 'shipment.shipped', order_id: order.id, tracking_id: 'TRK-1')

      expect(order.reload.transaction_id).to eq('TRK-1')
    end

    it 'leaves untouched attributes alone' do
      order.update!(notes: 'keep me')
      described_class.call(event: 'shipment.shipped', order_id: order.id)

      expect(order.reload.notes).to eq('keep me')
    end

    it 'accepts a raw JSON payload' do
      result = described_class.call({ event: 'shipment.shipped', order_id: order.id }.to_json)

      expect(result.success?).to be true
    end

    it 'returns unprocessable_content for an unknown event' do
      result = described_class.call(event: 'shipment.exploded', order_id: order.id)

      expect(result.success?).to be false
      expect(result.status).to eq(:unprocessable_content)
      expect(result.errors.first).to include('shipment.exploded')
    end

    it 'returns unprocessable_content when the event is missing' do
      expect(described_class.call({}).status).to eq(:unprocessable_content)
    end

    it 'returns not_found for an unknown order' do
      result = described_class.call(event: 'shipment.shipped', order_id: -1)

      expect(result.success?).to be false
      expect(result.status).to eq(:not_found)
    end

    it 'returns unprocessable_content for malformed JSON' do
      expect(described_class.call('{not json').status).to eq(:unprocessable_content)
    end
  end
end
