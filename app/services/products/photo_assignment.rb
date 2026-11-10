# frozen_string_literal: true

module Products
  class PhotoAssignment < ApplicationService
    def self.assign_photos(product:, photo_ids:)
      return if photo_ids.blank?

      ids = Array(photo_ids).reject(&:blank?)
      ProductPhoto.where(id: ids, product_id: nil).update_all(product_id: product.id)
    end
  end
end
