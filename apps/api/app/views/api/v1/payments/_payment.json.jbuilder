# frozen_string_literal: true

json.cache! ['payment_partial', payment.id, payment.updated_at, payment.order&.updated_at] do
  json.id payment.id
  json.order_id payment.order_id
  json.amount payment.amount
  json.currency payment.currency
  json.status payment.status
  json.payment_method payment.payment_method
  json.created_at payment.created_at
  json.updated_at payment.updated_at

  if payment.order.present?
    json.order do
      json.partial! 'api/v1/orders/order', order: payment.order
    end
  end
end
