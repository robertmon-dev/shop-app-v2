# frozen_string_literal: true

json.cache! ['product_comment_partial', product_comment.id, product_comment.updated_at] do
  json.id product_comment.id
  json.user_id product_comment.user_id
  json.content product_comment.content
  json.parent_id product_comment.parent_id if product_comment.parent_id.present?
  json.created_at product_comment.created_at
  json.updated_at product_comment.updated_at

  if product_comment.replies.any?
    json.replies product_comment.replies, partial: 'api/v1/products/product_comment', as: :product_comment
  end
end
