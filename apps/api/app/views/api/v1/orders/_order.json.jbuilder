# frozen_string_literal: true

json.cache! ['order_partial', order.id, order.updated_at, order.items.maximum(:updated_at) || Time.current] do
  json.id order.id
  json.user_id order.user_id
  json.total_amount order.total_amount
  json.status order.status
  json.payment_status order.payment_status
  json.created_at order.created_at
  json.updated_at order.updated_at

  json.items order.items do |item|
    json.id item.id
    json.product_name item.product.name
    json.quantity item.quantity
    json.price_at_purchase item.price_at_purchase
    json.subtotal item.subtotal
  end
end
