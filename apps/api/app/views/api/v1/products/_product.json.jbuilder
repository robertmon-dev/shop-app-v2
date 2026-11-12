# frozen_string_literal: true

json.cache! [
  'product_partial',
  product.id,
  product.updated_at,
  product.product_photos.maximum(:updated_at) || Time.current,
  product.product_likes.maximum(:updated_at) || Time.current,
  product.comments.maximum(:updated_at) || Time.current
] do
  json.id product.id
  json.name product.name
  json.description product.description
  json.price product.price
  json.stock_quantity product.stock_quantity
  json.average_rating product.average_rating if product.respond_to?(:average_rating)
  json.likes_count product.product_likes.count
  json.comments_count product.comments.count
  json.created_at product.created_at
  json.updated_at product.updated_at

  json.photos product.product_photos do |photo|
    json.partial! 'api/v1/products/product_photo', product_photo: photo
  end

  json.likes product.product_likes do |like|
    json.partial! 'api/v1/products/product_like', product_like: like
  end

  json.comments product.comments.where(parent_id: nil) do |comment|
    json.partial! 'api/v1/products/product_comment', product_comment: comment
  end

  json.categories product.categories do |category|
    json.partial! 'api/v1/products/product_category', category: category
  end
end
