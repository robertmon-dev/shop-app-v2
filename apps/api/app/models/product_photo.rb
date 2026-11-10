# frozen_string_literal: true

class ProductPhoto < ApplicationRecord
  belongs_to :product, optional: true
  has_one_attached :image

  def image_url
    return url if url.present?
    return nil unless image.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      image, host: ENV.fetch('APP_HOST', 'http://localhost:3000')
    )
  rescue StandardError => e
    Rails.logger.error "ProductPhoto##{id}: could not build image url - #{e.message}"
    nil
  end
end
