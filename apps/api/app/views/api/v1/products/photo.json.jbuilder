# frozen_string_literal: true

json.product_photo do
  json.partial! 'api/v1/products/product_photo', product_photo: @product_photo
end
