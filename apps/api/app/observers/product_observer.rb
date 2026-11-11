# frozen_string_literal: true

class ProductObserver < ApplicationObserver
  observe :product

  def after_create(product)
    Rails.logger.info "ProductObserver: New product added (ID: #{product.id}, Name: #{product.name})"
  end

  def after_update(product)
    Rails.logger.info "ProductObserver: Product updated (ID: #{product.id}, Name: #{product.name})"
  end

  def after_destroy(product)
    Rails.logger.info "ProductObserver: Product deleted (ID: #{product.id})"
  end
end
