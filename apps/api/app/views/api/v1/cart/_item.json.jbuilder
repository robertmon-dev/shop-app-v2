# frozen_string_literal: true

json.item_id item.id
json.quantity item.quantity
json.price_at_purchase item.product.price
json.subtotal item.quantity * item.product.price
json.product do
  json.id item.product.id
  json.name item.product.name
end
