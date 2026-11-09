# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::RefundCreationService, type: :service do
  let(:user) { create(:user) }
  let(:order) { create(:order, user: user, status: :delivered, payment_status: :paid) }
  let(:refund_params) { { reason: 'damaged', description: 'Arrived broken' } }

  describe '.call' do
    subject(:result) { described_class.call(user: user, order: order, refund_params: refund_params) }

    it 'creates a refund for the order' do
      expect { result }.to change(Refund, :count).by(1)
    end

    it 'returns a created result carrying the refund' do
      expect(result.success?).to be true
      expect(result.status).to eq(:created)
      expect(result.data[:refund]).to be_a(Refund)
    end

    it 'assigns the requesting user and the order' do
      refund = result.data[:refund]

      expect(refund.user).to eq(user)
      expect(refund.order).to eq(order)
    end

    it 'starts in the pending state with a refund date' do
      refund = result.data[:refund]

      expect(refund.status_pending?).to be true
      expect(refund.refund_date).to be_present
    end

    it 'returns not_found without a user' do
      outcome = described_class.call(user: nil, order: order, refund_params: refund_params)

      expect(outcome.status).to eq(:not_found)
    end

    it 'returns not_found without an order' do
      outcome = described_class.call(user: user, order: nil, refund_params: refund_params)

      expect(outcome.status).to eq(:not_found)
    end

    context 'when the order has not been paid' do
      let(:order) { create(:order, user: user, status: :delivered, payment_status: :unpaid) }

      it 'refuses to create a refund' do
        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
      end
    end

    context 'when the order has not shipped yet' do
      let(:order) { create(:order, user: user, status: :pending, payment_status: :paid) }

      it 'refuses to create a refund' do
        expect(result.status).to eq(:unprocessable_content)
      end
    end

    context 'when a refund already exists' do
      before { create(:refund, order: order, user: user) }

      it 'returns a conflict' do
        expect(result.status).to eq(:conflict)
      end

      it 'does not create a second refund' do
        expect { result }.not_to change(Refund, :count)
      end
    end

    context 'when a previous refund was cancelled' do
      before { create(:refund, :cancelled, order: order, user: user) }

      it 'allows a new request' do
        expect(result.success?).to be true
      end
    end

    context 'with invalid params' do
      let(:refund_params) { { reason: '', description: '' } }

      it 'returns a validation failure' do
        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
      end
    end
  end
end
