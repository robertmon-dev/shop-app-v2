# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::ProductUpdateService, type: :service do
  let!(:product) { create(:product, name: 'Old Name') }
  let(:management_service) { class_double(Services::ProductManagementService) }
  let(:caching_service) { class_double(Services::ProductCachingService) }
  let(:valid_params) do
    {
      name: 'New Name',
      price: 199.99,
      product_photo_ids: [1, 2]
    }
  end

  before do
    stub_const('Services::ProductManagementService', management_service)
    stub_const('Services::ProductCachingService', caching_service)
    allow(management_service).to receive(:assign_photos)
    allow(caching_service).to receive(:invalidate_for_product)
  end

  describe '.call' do
    context 'with valid parameters' do
      it 'updates the product attributes' do
        described_class.call(product, valid_params)
        expect(product.reload.name).to eq('New Name')
        expect(product.reload.price).to eq(199.99)
      end

      it 'calls the ProductManagementService to assign photos' do
        expect(management_service).to receive(:assign_photos).with(product: product, photo_ids: [1, 2])
        described_class.call(product, valid_params)
      end

      it 'calls the ProductCachingService to invalidate caches' do
        expect(caching_service).to receive(:invalidate_for_product).with(product)
        described_class.call(product, valid_params)
      end

      it 'returns a successful result' do
        result = described_class.call(product, valid_params)
        expect(result.success?).to be true
        expect(result.status).to eq(:ok)
        expect(result.data[:product]).to eq(product)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) { valid_params.merge(name: '') }

      it 'does not update the product' do
        original_name = product.name
        described_class.call(product, invalid_params)
        expect(product.reload.name).to eq(original_name)
      end

      it 'does not call the downstream services' do
        expect(management_service).not_to receive(:assign_photos)
        expect(caching_service).not_to receive(:invalidate_for_product)
        described_class.call(product, invalid_params)
      end

      it 'returns an unprocessable_content result with errors' do
        result = described_class.call(product, invalid_params)
        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
        expect(result.errors).to include("Name can't be blank")
      end
    end

    context 'when a downstream service raises an error' do
      before do
        allow(caching_service).to receive(:invalidate_for_product).and_raise(StandardError, 'Cache is down')
        allow(Rails.logger).to receive(:error)
      end

      it 'does not update the product due to transaction rollback' do
        original_name = product.name
        described_class.call(product, valid_params)
        expect(product.reload.name).to eq(original_name)
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with('An unexpected error occurred: Cache is down')
        described_class.call(product, valid_params)
      end

      it 'returns an internal_server_error result' do
        result = described_class.call(product, valid_params)
        expect(result.success?).to be false
        expect(result.status).to eq(:internal_server_error)
      end
    end
  end
end
