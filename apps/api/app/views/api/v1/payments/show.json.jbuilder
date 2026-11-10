# frozen_string_literal: true

json.payment do
  json.partial! 'api/v1/payments/payment', payment: @payment
end
