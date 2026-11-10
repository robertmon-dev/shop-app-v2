# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::ProductManagementService, type: :service do
  let!(:product) { create(:product) }

  describe '.assign_photos' do
    context 'with valid, unassigned photo IDs' do
      let!(:photo1) { create(:product_photo, product_id: nil) }
      let!(:photo2) { create(:product_photo, product_id: nil) }

      it 'assigns the photos to the product' do
        photo_ids = [photo1.id, photo2.id]
        described_class.assign_photos(product: product, photo_ids: photo_ids)

        expect(photo1.reload.product).to eq(product)
        expect(photo2.reload.product).to eq(product)
      end
    end

    context 'when photo_ids include an already assigned photo' do
      let!(:unassigned_photo) { create(:product_photo, product_id: nil) }
      let!(:other_product) { create(:product) }
      let!(:assigned_photo) { create(:product_photo, product: other_product) }

      it 'only assigns the unassigned photos' do
        photo_ids = [unassigned_photo.id, assigned_photo.id]
        described_class.assign_photos(product: product, photo_ids: photo_ids)

        expect(unassigned_photo.reload.product).to eq(product)
      end

      it 'does not re-assign the already assigned photo' do
        photo_ids = [unassigned_photo.id, assigned_photo.id]
        described_class.assign_photos(product: product, photo_ids: photo_ids)

        expect(assigned_photo.reload.product).to eq(other_product)
        expect(assigned_photo.reload.product).not_to eq(product)
      end
    end

    context 'when photo_ids is nil or empty' do
      it 'does not raise an error and does nothing for nil' do
        expect do
          described_class.assign_photos(product: product, photo_ids: nil)
        end.not_to raise_error
      end

      it 'does not raise an error and does nothing for an empty array' do
        expect do
          described_class.assign_photos(product: product, photo_ids: [])
        end.not_to raise_error
      end
    end

    context 'when photo_ids contains blank values' do
      let!(:photo) { create(:product_photo, product_id: nil) }

      it 'filters out blank values and assigns the valid photo' do
        photo_ids = ['', photo.id, nil]
        described_class.assign_photos(product: product, photo_ids: photo_ids)
        expect(photo.reload.product).to eq(product)
      end
    end
  end
end
