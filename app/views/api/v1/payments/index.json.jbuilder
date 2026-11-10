# frozen_string_literal: true

json.payments @payments, partial: 'api/v1/payments/payment', as: :payment
