# frozen_string_literal: true

json.item_id item[:item_id]
json.quantity item[:quantity]
json.price_at_purchase item[:price]
json.subtotal item[:subtotal]
json.product do
  json.id item[:product][:id]
  json.name item[:product][:name]
end
