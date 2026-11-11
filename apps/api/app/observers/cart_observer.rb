# frozen_string_literal: true

class CartObserver < ApplicationObserver
  observe :item

  def after_create(cart_item)
    return if cart_item.user.nil?

    Rails.logger.info "CartObserver: Item added to cart (User: #{cart_item.user.id}, Product: #{cart_item.product.name}, User: #{cart_item.user.id})"
  end

  def after_update(cart_item)
    return if cart_item.user.nil?

    Rails.logger.info "CartObserver: Cart item updated (User: #{cart_item.user.id}, Product: #{cart_item.product.name}, New Quantity: #{cart_item.quantity})"
  end

  def after_destroy(cart_item)
    return if cart_item.user.nil?

    Rails.logger.info "CartObserver: Cart item removed (User: #{cart_item.user.id}, Product: #{cart_item.product.name})"
  end
end
