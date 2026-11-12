# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Product, type: :model do
  before(:all) do
    fixture_path = Rails.root.join('spec/fixtures/files')
    FileUtils.mkdir_p(fixture_path) unless File.directory?(fixture_path)
    unless File.exist?(fixture_path.join('test_image.png'))
      File.write(fixture_path.join('test_image.png'), 'fake image data')
    end
  end

  subject { create(:product) }

  describe 'associations' do
    it { should have_many(:product_photos).dependent(:destroy) }
    it { should have_many(:comments).dependent(:destroy) }
    it { should have_many(:product_rates).dependent(:destroy) }
  end

  describe 'nested attributes' do
    it { should accept_nested_attributes_for(:product_photos).allow_destroy(true) }

    it 'can create product_photos through nested attributes' do
      file = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')

      product_params = {
        name: 'Laptop z dodatkami',
        price: 4500.0,
        vat_rate: 0.23,
        weight_kg: 10,
        length_cm: 10.5,
        width_cm: 10.5,
        height_cm: 10.5,
        product_photos_attributes: [
          { image: file },
          { image: file }
        ]
      }

      expect { Product.create!(product_params) }.to change(ProductPhoto, :count).by(2)
    end

    it 'can destroy product_photos through nested attributes' do
      product = create(:product)
      photo = create(:product_photo, product: product)

      product_params = {
        product_photos_attributes: [
          { id: photo.id, _destroy: '1' }
        ]
      }

      expect { product.update!(product_params) }.to change(ProductPhoto, :count).by(-1)
    end
  end

  describe 'creation' do
    it 'is valid with valid attributes' do
      expect(build(:product)).to be_valid
    end
  end

  describe 'stock_quantity' do
    it 'is optional, meaning stock is not tracked' do
      expect(build(:product, stock_quantity: nil)).to be_valid
    end

    it 'accepts zero' do
      expect(build(:product, stock_quantity: 0)).to be_valid
    end

    it 'rejects negative and fractional values' do
      expect(build(:product, stock_quantity: -1)).not_to be_valid
      expect(build(:product, stock_quantity: 1.5)).not_to be_valid
    end
  end
end
