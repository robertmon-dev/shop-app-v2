# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::ProductCachingService, type: :service do
  let!(:product) { create(:product) }
  let(:cache_store) { Rails.cache }

  before do
    cache_store.clear
  end

  describe '.fetch_all' do
    let(:page) { 1 }

    it 'writes the result to the cache when cache is empty' do
      expect(cache_store).to receive(:fetch).twice.and_call_original
      described_class.fetch_all(page)
    end

    it 'reads from the cache on the second call' do
      described_class.fetch_all(page)

      expect(Product).not_to receive(:with_details)
      described_class.fetch_all(page)
    end
  end

  describe '.fetch_one' do
    it 'writes to cache if product exists and is not cached' do
      expect(cache_store).to receive(:fetch).with("product:#{product.id}", expires_in: 1.hour).and_call_original
      described_class.fetch_one(product.id)
    end

    it 'returns result with nil data if product does not exist' do
      expect(described_class.fetch_one(-1).data).to be_nil
    end
  end

  describe '.invalidate_for_product' do
    it 'deletes the product key and invalidates index pages' do
      expect(described_class).to receive(:invalidate_for_product)
      described_class.invalidate_for_product(product)
    end
  end
end
