# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Invoices::Creation, type: :service do
  let(:user) { create(:user, :with_location) }
  let(:location) { user.user_detail.locations.first }
  let(:product) { create(:product, price: 100, vat_rate: 0.23) }
  let(:order) { create(:order, user: user, location: location) }
  let!(:item) { create(:item, order: order, product: product, quantity: 2, price_at_purchase: 100) }
  let(:payment) { create(:payment, :paid, order: order, amount: 246.00) }

  describe '.call' do
    subject(:result) { described_class.call(payment) }

    it 'creates an invoice for the payment' do
      expect { result }.to change(Invoice, :count).by(1)
    end

    it 'returns a created result carrying the invoice' do
      expect(result.success?).to be true
      expect(result.status).to eq(:created)
      expect(result.data[:invoice]).to be_a(Invoice)
    end

    it 'builds one invoice item per order item' do
      expect { result }.to change(InvoiceItem, :count).by(1)
    end

    it 'computes net, vat and gross totals from the order items' do
      invoice = result.data[:invoice]

      expect(invoice.total_net).to eq(200.00)
      expect(invoice.tax_value).to eq(46.00)
      expect(invoice.total_gross).to eq(246.00)
    end

    it 'links the invoice to the order and the payment' do
      invoice = result.data[:invoice]

      expect(invoice.order).to eq(order)
      expect(invoice.payment).to eq(payment)
      expect(order.reload.invoice).to eq(invoice)
    end

    it 'snapshots the delivery address' do
      expect(result.data[:invoice].full_address).to eq(location.full_address)
    end

    context 'with sequential invoice numbers' do
      it 'increments the sequence within the current month' do
        first = described_class.call(payment).data[:invoice]
        other_payment = create(:payment, :paid, order: create(:order, user: user, location: location))
        create(:item, order: other_payment.order, product: product)

        second = described_class.call(other_payment).data[:invoice]

        expect(second.invoice_number.split('/').last.to_i).to eq(first.invoice_number.split('/').last.to_i + 1)
      end
    end

    context 'when the buyer is an entrepreneur' do
      let(:user) { create(:user, :with_location, role: :entrepreneur) }

      before do
        detail = user.user_detail
        create(:entrepreneur_detail, user_detail: detail, business_name: 'Acme sp. z o.o.', nip: '9876543210')
        detail.reload
      end

      it 'uses the business name and tax id' do
        invoice = result.data[:invoice]

        expect(invoice.buyer_name).to eq('Acme sp. z o.o.')
        expect(invoice.buyer_tax_id).to eq('9876543210')
      end
    end

    context 'when the payment already has an invoice' do
      before { described_class.call(payment) }

      it 'does not create a second invoice' do
        expect { described_class.call(payment.reload) }.not_to change(Invoice, :count)
      end

      it 'returns a conflict result' do
        expect(described_class.call(payment.reload).status).to eq(:conflict)
      end
    end

    context 'when the order cannot be found' do
      before { allow(Order).to receive(:includes).and_raise(ActiveRecord::RecordNotFound) }

      it 'returns a failure result' do
        expect(result.success?).to be false
      end
    end
  end
end
