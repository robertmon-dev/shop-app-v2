# frozen_string_literal: true

require 'swagger_helper'

describe 'Invoices API' do
  let!(:admin) { create(:user, :admin, :with_detail) }
  let!(:user) { create(:user, :regular, :with_detail) }
  let!(:other_user) { create(:user, :regular, :with_detail) }
  let!(:invoice) { create(:invoice, user: user) }
  let!(:other_invoice) { create(:invoice, user: other_user) }
  let(:Authorization) { bearer(user) }
  let(:id) { invoice.id }

  before { create(:invoice_item, invoice: invoice) }

  path '/api/v1/invoices' do
    get 'Lists invoices (all for an admin, own otherwise)' do
      tags 'Invoices'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :page, in: :query, type: :integer, required: false

      response '200', 'returns a paginated list of invoices' do
        let(:Authorization) { bearer(admin) }
        let(:page) { 1 }
        schema envelope_schema({ invoices: list(:Invoice) }, meta: true)
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid' }
        let(:page) { 1 }
        schema failure_schema
        run_test!
      end
    end
  end

  path '/api/v1/invoices/me' do
    get "Lists the current user's invoices" do
      tags 'Invoices'
      produces 'application/json'
      security [Bearer: []]

      response '200', 'returns own invoices' do
        schema envelope_schema({ invoices: list(:Invoice) }, meta: true)
        run_test!
      end
    end
  end

  path '/api/v1/invoices/{id}' do
    parameter name: :id, in: :path, type: :integer

    get 'Retrieves an invoice' do
      tags 'Invoices'
      produces 'application/json'
      security [Bearer: []]

      response '200', 'returns the invoice' do
        schema envelope_schema(invoice: ref(:Invoice))
        run_test!
      end

      response '403', "forbidden for another user's invoice" do
        let(:id) { other_invoice.id }
        schema failure_schema
        run_test!
      end
    end
  end

  path '/api/v1/invoices/{id}/download' do
    parameter name: :id, in: :path, type: :integer

    get 'Downloads the invoice as a base64 encoded PDF' do
      tags 'Invoices'
      produces 'application/json'
      security [Bearer: []]

      response '200', 'returns the rendered PDF' do
        schema data_schema(:InvoiceDownload)
        run_test!
      end
    end
  end
end
