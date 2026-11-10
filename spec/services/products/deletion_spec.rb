# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::ProductDeletionService, type: :service do
  let(:caching_service) { class_double(Services::ProductCachingService) }

  before do
    # Stubbing the observer instance as you suggested to prevent its callbacks from running.
    # This is good practice for isolating service tests from observer side-effects.
    allow(ProductObserver.instance).to receive(:after_create)
    allow(ProductObserver.instance).to receive(:after_update)
    allow(ProductObserver.instance).to receive(:after_destroy)

    stub_const('Services::ProductCachingService', caching_service)
    allow(caching_service).to receive(:invalidate_for_product)
  end

  describe '.call' do
    context 'when deletion is successful' do
      let!(:product) { create(:product) }

      it 'destroys the product' do
        expect do
          described_class.call(product)
        end.to change(Product, :count).by(-1)
      end

      it 'invalidates the index pages cache' do
        expect(caching_service).to receive(:invalidate_for_product)
        described_class.call(product)
      end

      it 'returns a successful result' do
        result = described_class.call(product)
        expect(result.success?).to be true
        expect(result.status).to eq(:no_content)
      end
    end

    context 'when deletion is prevented by a callback' do
      let!(:product) { create(:product) }

      before do
        allow(product).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed.new('Cannot delete', product))
        allow(Rails.logger).to receive(:error)
      end

      it 'does not destroy the product' do
        expect do
          described_class.call(product)
        end.not_to change(Product, :count)
      end

      it 'does not invalidate the cache' do
        expect(caching_service).not_to receive(:invalidate_for_product)
        described_class.call(product)
      end

      it 'returns an not_modified result' do
        result = described_class.call(product)
        expect(result.success?).to be false
        expect(result.status).to eq(:not_modified)
      end
    end

    context 'when cache invalidation fails' do
      let!(:product) { create(:product) }

      before do
        allow(caching_service).to receive(:invalidate_for_product).and_raise(StandardError, 'Cache error')
        allow(Rails.logger).to receive(:error)
      end

      it 'does not destroy the product due to transaction rollback' do
        expect do
          described_class.call(product)
        end.not_to change(Product, :count)
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/An unexpected error occurred: Cache error/)
        described_class.call(product)
      end

      it 'returns an internal_server_error result' do
        result = described_class.call(product)
        expect(result.success?).to be false
        expect(result.status).to eq(:internal_server_error)
      end
    end
  end
end
