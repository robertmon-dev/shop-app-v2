# frozen_string_literal: true

json.cache! ['product_like_partial', product_like.id, product_like.updated_at] do
  json.id product_like.id
  json.user_id product_like.user_id
  json.created_at product_like.created_at
end
