# frozen_string_literal: true

json.orders @orders, partial: 'api/v1/orders/order', as: :order
