# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::InvoicePDFGenerationService, type: :service do
  let(:invoice) { create(:invoice, invoice_number: 'FV/2026/01/7') }
  let!(:invoice_item) { create(:invoice_item, invoice: invoice, name: 'Śrubokręt płaski') }

  describe '.call' do
    subject(:result) { described_class.call(invoice.reload) }

    it 'returns a successful result' do
      expect(result.success?).to be true
    end

    it 'renders a PDF document' do
      expect(result.data[:pdf]).to start_with('%PDF')
    end

    it 'names the file after the invoice number with slashes replaced' do
      expect(result.data[:filename]).to eq('FV-2026-01-7.pdf')
    end

    it 'includes every invoice item in the table' do
      expect(described_class.new(invoice.reload).send(:table_data).size).to eq(2)
    end

    context 'when no unicode font is available' do
      before do
        allow(File).to receive(:exist?).and_return(false)
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('INVOICE_PDF_FONT_PATH', nil).and_return(nil)
      end

      it 'still renders by transliterating the text' do
        expect(result.success?).to be true
        expect(result.data[:pdf]).to start_with('%PDF')
      end
    end
  end
end
