# frozen_string_literal: true

require 'rails_helper'
RSpec.describe ProductPhoto, type: :model do
  before(:all) do
    fixture_path = Rails.root.join('spec/fixtures/files')
    FileUtils.mkdir_p(fixture_path) unless File.directory?(fixture_path)
    unless File.exist?(fixture_path.join('test_image.png'))
      File.write(fixture_path.join('test_image.png'), 'fake image data')
    end
  end

  describe 'associations' do
    it { should belong_to(:product).optional }
  end

  describe 'attachments' do
    subject { create(:product_photo) }

    it 'has one attached image' do
      expect(subject.image).to be_an_instance_of(ActiveStorage::Attached::One)
    end
  end

  describe 'creation' do
    context 'with an associated product' do
      it 'is valid' do
        product = create(:product)
        photo = build(:product_photo, product: product)
        expect(photo).to be_valid
      end
    end

    context 'without an associated product' do
      it 'is still valid because the association is optional' do
        photo = build(:product_photo, product: nil)
        expect(photo).to be_valid
      end
    end

    context 'without an attached image' do
      it 'is still valid as Active Storage does not add a presence validation by default' do
        photo = build(:product_photo)
        photo.image.detach
        expect(photo).to be_valid
      end
    end
  end
end
