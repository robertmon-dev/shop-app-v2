# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payment, type: :model do
  let!(:order) { create(:order) }

  describe 'associations' do
    it { should belong_to(:order) }
  end

  describe 'enums' do
    it do
      should define_enum_for(:status)
        .with_values(unpaid: 0, paid: 1, failed: 2, refunded: 3)
        .with_prefix(:status)
    end
  end

  describe 'validations' do
    subject { create(:payment, order: order) }

    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:payment_method) }
    it { should validate_presence_of(:currency) }
    it { should validate_presence_of(:stripe_payment_intent_id) }
    it { should validate_uniqueness_of(:stripe_payment_intent_id) }
    it { should validate_uniqueness_of(:stripe_charge_id).allow_nil }
  end

  describe 'callbacks' do
    describe '#set_default_currency' do
      it 'sets the currency to PLN on creation if not provided' do
        payment = build(:payment, order: order, currency: nil)
        payment.valid?
        expect(payment.currency).to eq('pln')
      end

      it 'does not override an existing currency' do
        payment = build(:payment, order: order, currency: 'USD')
        payment.valid?
        expect(payment.currency).to eq('USD')
      end
    end
  end

  describe 'instance methods' do
    let(:payment) { create(:payment, order: order, status: :unpaid) }

    describe '#mark_as_paid!' do
      it 'updates the status to paid' do
        payment.mark_as_paid!
        expect(payment.reload.status_paid?).to be(true)
      end
    end

    describe '#mark_as_failed!' do
      it 'updates the status to failed' do
        payment.mark_as_failed!
        expect(payment.reload.status_failed?).to be(true)
      end

      it 'sets the error_message when provided' do
        error_msg = 'Insufficient funds'
        payment.mark_as_failed!(error_msg)
        expect(payment.reload.error_message).to eq(error_msg)
      end
    end

    describe '#mark_as_refunded!' do
      it 'updates the status to refunded' do
        payment.mark_as_refunded!
        expect(payment.reload.status_refunded?).to be(true)
      end
    end
  end

  describe '.create_from_payment_intent' do
    let!(:order) { create(:order, stripe_payment_intent_id: 'pi_12345') }

    let(:charge) do
      OpenStruct.new(
        id: 'ch_67890',
        payment_method_details: OpenStruct.new(
          type: 'card',
          card: OpenStruct.new(brand: 'visa')
        )
      )
    end

    let(:payment_intent) do
      OpenStruct.new(
        id: 'pi_12345',
        amount_received: 9999,
        currency: 'pln',
        latest_charge: charge
      )
    end

    context 'when an order with the corresponding payment_intent_id exists' do
      it 'creates a new Payment record' do
        expect do
          described_class.create_from_payment_intent(payment_intent)
        end.to change(Payment, :count).by(1)
      end

      it 'assigns correct attributes to the new payment' do
        payment = described_class.create_from_payment_intent(payment_intent)
        expect(payment.order).to eq(order)
        expect(payment.amount).to eq(99.99)
        expect(payment.status_paid?).to be(true)
        expect(payment.payment_method).to eq('card (visa)')
        expect(payment.stripe_payment_intent_id).to eq('pi_12345')
        expect(payment.stripe_charge_id).to eq('ch_67890')
        expect(payment.currency).to eq('PLN')
      end
    end

    context 'when an order with the corresponding payment_intent_id does not exist' do
      it 'raises an ActiveRecord::RecordNotFound error' do
        non_existent_payment_intent = OpenStruct.new(id: 'pi_non_existent')

        expect do
          described_class.create_from_payment_intent(non_existent_payment_intent)
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
