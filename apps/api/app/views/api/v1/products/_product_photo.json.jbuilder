# frozen_string_literal: true

json.cache! ['product_photo_partial', product_photo.id, product_photo.updated_at] do
  json.id product_photo.id
  json.url product_photo.url
  json.thumbnail_url product_photo.thumbnail_url if product_photo.respond_to?(:thumbnail_url)
  json.created_at product_photo.created_at
  json.updated_at product_photo.updated_at
end
