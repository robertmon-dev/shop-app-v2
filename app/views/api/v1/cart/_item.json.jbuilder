# frozen_string_literal: true

json.item_id item.id
json.quantity item.quantity
json.price_at_purchase item.price_at_purchase
json.subtotal item.quantity * item.price_at_purchase
json.product do
  json.id item.product.id
  json.name item.product.name
end
