# frozen_string_literal: true

class OrderObserver < ApplicationObserver
  observe :order

  def after_create(order)
    Rails.logger.info "OrderObserver: Order created (Order: #{order.id}, User: #{order.user.id})"
  end

  def after_update(order)
    if order.payment_status_paid? || order.status_cancelled?
      payload = order.to_order_dto
      Messaging::Producer.produce(payload)
    end

    Rails.logger.info "OrderObserver: Order updated (Order: #{order.id}, User: #{order.user.id})"
  end

  def after_destroy(order)
    Rails.logger.info "OrderObserver: Order deleted (Order: #{order.id})"
  end
end
