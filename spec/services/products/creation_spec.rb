# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::ProductCreationService, type: :service do
  let(:management_service) { class_double(Services::ProductManagementService) }
  let(:caching_service) { class_double(Services::ProductCachingService) }
  let(:valid_params) do
    {
      name: 'New Gadget',
      price: 99.99,
      vat_rate: 0.23,
      weight_kg: 10,
      height_cm: 10,
      width_cm: 10,
      length_cm: 10,
      description: 'A very useful gadget.',
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
      it 'creates a new product' do
        expect do
          described_class.call(valid_params)
        end.to change(Product, :count).by(1)
      end

      it 'calls the ProductManagementService to assign photos' do
        expect(management_service).to receive(:assign_photos).with(
          product: an_instance_of(Product),
          photo_ids: [1, 2]
        )
        described_class.call(valid_params)
      end

      it 'calls the ProductCachingService to invalidate the cache' do
        expect(caching_service).to receive(:invalidate_for_product)
        described_class.call(valid_params)
      end

      it 'returns a successful result' do
        result = described_class.call(valid_params)
        expect(result.success?).to be true
        expect(result.status).to eq(:created)
        expect(result.data[:product]).to be_a(Product)
        expect(result.data[:product].name).to eq('New Gadget')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) { valid_params.merge(name: '') }

      it 'does not create a new product' do
        expect do
          described_class.call(invalid_params)
        end.not_to change(Product, :count)
      end

      it 'does not call the downstream services' do
        expect(management_service).not_to receive(:assign_photos)
        expect(caching_service).not_to receive(:invalidate_for_product)
        described_class.call(invalid_params)
      end

      it 'returns an unprocessable_content result with errors' do
        result = described_class.call(invalid_params)
        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
        expect(result.errors).to include("Name can't be blank")
      end
    end

    context 'when a downstream service raises an error' do
      before do
        allow(management_service).to receive(:assign_photos).and_raise(StandardError, 'Something went wrong')
        allow(Rails.logger).to receive(:error)
      end

      it 'does not create a new product due to transaction rollback' do
        expect do
          described_class.call(valid_params)
        end.not_to change(Product, :count)
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with('An unexpected error occurred: Something went wrong')
        described_class.call(valid_params)
      end

      it 'returns an internal_server_error result' do
        result = described_class.call(valid_params)
        expect(result.success?).to be false
        expect(result.status).to eq(:internal_server_error)
        expect(result.errors.first).to eq('Unknown error has occured during the operation')
      end
    end
  end
end
