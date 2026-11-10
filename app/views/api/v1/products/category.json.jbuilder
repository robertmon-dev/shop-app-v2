# frozen_string_literal: true

json.category do
  json.partial! 'api/v1/products/product_category', category: @category
end
