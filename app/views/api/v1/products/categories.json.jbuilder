# frozen_string_literal: true

json.categories @categories do |category|
  json.partial! 'api/v1/products/product_category', category: category
end
