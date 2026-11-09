# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::ProductPhotoCreationService, type: :service do
  let(:product) { create(:product) }

  def upload(filename: 'test_image.png', type: 'image/png')
    Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), type,
                                 original_filename: filename)
  end

  describe '.call' do
    it 'creates a product photo' do
      expect { described_class.call(image: upload, product: product) }.to change(ProductPhoto, :count).by(1)
    end

    it 'returns a created result with the photo' do
      result = described_class.call(image: upload, product: product)

      expect(result.success?).to be true
      expect(result.status).to eq(:created)
      expect(result.data[:product_photo]).to be_a(ProductPhoto)
    end

    it 'attaches the image' do
      photo = described_class.call(image: upload, product: product).data[:product_photo]

      expect(photo.image).to be_attached
    end

    it 'assigns the photo to the product' do
      photo = described_class.call(image: upload, product: product).data[:product_photo]

      expect(photo.product).to eq(product)
    end

    it 'allows an unassigned photo' do
      photo = described_class.call(image: upload, product: nil).data[:product_photo]

      expect(photo.product).to be_nil
    end

    it 'rejects a missing image' do
      result = described_class.call(image: nil, product: product)

      expect(result.success?).to be false
      expect(result.status).to eq(:unprocessable_content)
    end

    it 'rejects an unsupported content type' do
      result = described_class.call(image: upload(type: 'application/pdf'), product: product)

      expect(result.success?).to be false
      expect(result.errors.first).to include('application/pdf')
    end

    it 'rejects an oversized image' do
      oversized = upload
      allow(oversized).to receive(:size).and_return(described_class::MAX_BYTES + 1)

      expect(described_class.call(image: oversized, product: product).success?).to be false
    end
  end
end
