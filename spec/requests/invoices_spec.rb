# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Invoices', type: :request do
  let(:json) { JSON.parse(response.body) }

  let(:admin) { create(:user, :admin, :with_detail) }
  let(:user) { create(:user, :regular, :with_detail) }
  let(:other_user) { create(:user, :regular, :with_detail) }

  let!(:user_invoice) { create(:invoice, user: user) }
  let!(:other_invoice) { create(:invoice, user: other_user) }

  def headers_for(actor)
    {
      'Authorization' => "Bearer #{Services::BearerService.encode({ user_id: actor.id }).data[:token]}",
      'Accept' => 'application/json'
    }
  end

  describe 'GET /api/v1/invoices' do
    it 'returns every invoice for an admin' do
      get '/api/v1/invoices', headers: headers_for(admin)

      expect(response).to have_http_status(:ok)
      expect(json['invoices'].size).to eq(2)
      expect(json['meta']['total_count']).to eq(2)
    end

    it "returns only the caller's invoices for a regular user" do
      get '/api/v1/invoices', headers: headers_for(user)

      expect(response).to have_http_status(:ok)
      expect(json['invoices'].map { |invoice| invoice['id'] }).to contain_exactly(user_invoice.id)
    end

    it 'rejects an unauthenticated request' do
      get '/api/v1/invoices'

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET /api/v1/invoices/me' do
    it "returns the caller's invoices" do
      get '/api/v1/invoices/me', headers: headers_for(user)

      expect(response).to have_http_status(:ok)
      expect(json['invoices'].map { |invoice| invoice['id'] }).to contain_exactly(user_invoice.id)
    end
  end

  describe 'GET /api/v1/invoices/:id' do
    it 'returns the invoice to its owner' do
      get "/api/v1/invoices/#{user_invoice.id}", headers: headers_for(user)

      expect(response).to have_http_status(:ok)
      expect(json['invoice']['invoice_number']).to eq(user_invoice.invoice_number)
    end

    it "forbids reading another user's invoice" do
      get "/api/v1/invoices/#{other_invoice.id}", headers: headers_for(user)

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns not found for an unknown invoice' do
      get '/api/v1/invoices/0', headers: headers_for(admin)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v1/invoices/:id/download' do
    before { create(:invoice_item, invoice: user_invoice) }

    it 'returns the rendered PDF to its owner' do
      get "/api/v1/invoices/#{user_invoice.id}/download", headers: headers_for(user)

      expect(response).to have_http_status(:ok)
      expect(json['filename']).to eq("#{user_invoice.invoice_number.tr('/', '-')}.pdf")
      expect(Base64.strict_decode64(json['pdf'])).to start_with('%PDF')
    end

    it "forbids downloading another user's invoice" do
      get "/api/v1/invoices/#{other_invoice.id}/download", headers: headers_for(user)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
