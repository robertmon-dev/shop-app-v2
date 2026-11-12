# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Refunds::Management, type: :service do
  describe '#complete' do
    let(:order) { create(:order, payment_status: :paid) }
    let!(:payment) { create(:payment, :paid, order: order) }
    let(:refund) { create(:refund, :processing, order: order) }

    before { allow(Stripe::Refund).to receive(:create).and_return(double(id: 're_1')) }

    it 'refunds the payment intent in Stripe, idempotently per refund' do
      described_class.new(refund).complete

      expect(Stripe::Refund).to have_received(:create).with(
        { payment_intent: payment.stripe_payment_intent_id, metadata: { refund_id: refund.id } },
        { idempotency_key: "refund-#{refund.id}" }
      )
    end

    it 'marks the refund, the payment and the order as refunded' do
      result = described_class.new(refund).complete

      expect(result.success?).to be true
      expect(refund.reload).to have_attributes(status: 'refunded', payment_status: 'refunded', payment_id: payment.id)
      expect(payment.reload.status).to eq('refunded')
      expect(order.reload.payment_status).to eq('refunded')
    end

    it 'leaves everything untouched when Stripe fails' do
      allow(Stripe::Refund).to receive(:create).and_raise(Stripe::APIConnectionError.new('down'))

      result = described_class.new(refund).complete

      expect(result.success?).to be false
      expect(refund.reload.status).to eq('processing')
      expect(payment.reload.status).to eq('paid')
    end

    it 'does not call Stripe for a refund that is not processing' do
      result = described_class.new(create(:refund, order: order)).complete

      expect(result.success?).to be false
      expect(Stripe::Refund).not_to have_received(:create)
    end

    it 'does not call Stripe twice for an already refunded refund' do
      result = described_class.new(create(:refund, :refunded, order: order)).complete

      expect(result.success?).to be false
      expect(Stripe::Refund).not_to have_received(:create)
    end

    context 'when the order has no paid payment' do
      let!(:payment) { create(:payment, :failed, order: order) }

      it 'fails without calling Stripe' do
        result = described_class.new(refund).complete

        expect(result.success?).to be false
        expect(Stripe::Refund).not_to have_received(:create)
      end
    end

    context 'when the order has no payment at all' do
      let!(:payment) { nil }

      it 'fails without calling Stripe' do
        result = described_class.new(refund).complete

        expect(result.success?).to be false
        expect(Stripe::Refund).not_to have_received(:create)
      end
    end
  end
end
