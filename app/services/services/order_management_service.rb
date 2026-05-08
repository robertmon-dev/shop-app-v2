# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  class OrderManagementService
    include Concerns::Handlers
    include Concerns::ResultHelpers

    def initialize(order)
      @order = order
    end

    def update(params)
      with_error_handling do
        unless @order.update(params)
          return unprocessable_content_result(record: @order, message: 'Order update failed due to validation errors.')
        end

        @order.reload
        return success_result(data: { order: @order }, message: 'Order updated successfully', status: :ok)
      end
    end

    def cancel
      unless @order.status_pending? || @order.status_processing?
        unprocessable_content_with_errors_result(errors: ["Cannot cancel order with status: #{@order.status}"],
                                                 message: "Cannot cancel order with status: #{@order.status}")
      end

      with_error_handling do
        if @order.update(status: :cancelled)
          return success_result(data: { order: @order }, message: 'Order cancelled successfully')
        end

        unprocessable_content(record: @order, message: 'Order cancellation failed due to validation errors.')
      end
    end

    def destroy
      with_error_not_destroyed_handling do
        @order.destroy
        destroy_success_result(message: 'Successfully destroyed order')
      end
    end

    def add(product, quantity)
      unless product && quantity.to_i.positive?
        unprocessable_content_with_errors_result(errors: ['Invalid product or quantity'],
                                                 message: 'Failed to add product: invalid input.')
      end

      result = resolve_status(product)
      return result if result.errors.present?

      with_error_handling do
        ActiveRecord::Base.transaction do
          item = @order.items.find_or_initialize_by(product_id: product.id)
          item.price_at_purchase ||= product.price
          item.increment!(:quantity, quantity.to_i)

          @order.save!
        end
        success_result(data: { order: @order }, message: 'Product added to order successfully')
      end
    end

    def remove(product, quantity = nil)
      result = resolve_status(product)
      return result if result.errors.present?

      with_error_not_destroyed_handling do
        ActiveRecord::Base.transaction do
          if quantity.nil?
            item.destroy!
          else
            quantity_to_remove = quantity.to_i
            unprocessable_result = resolve_quantity(quantity_to_remove)
            return unprocessable_result if unprocessable_result

            result.item.decrement!(:quantity, quantity_to_remove)
            result.item.destroy! if item.quantity <= 0
          end
          @order.items.reload
          @order.save!
        end
      end
    end

    def resolve_quantity(quantity_to_remove)
      if quantity_to_remove <= 0
        return unprocessable_content_with_errors_result(errors: ['Quantity must be a positive number.'],
                                                        message: 'Invalid quantity')
      end
      return unless quantity_to_remove > item.quantity

      unprocessable_content_with_errors_result(
        errors: ["Cannot remove #{remove_to_remove} items, only #{item.quantity} present."], message: 'Invalid quantity'
      )
    end

    def resolve_status(product)
      unless @order.status_pending? || @order.status_processing?
        unprocessable_content_with_errors_result(errors: ["Cannot modify order with status: #{@order.status}"],
                                                 message: "Cannot modify order with status: #{@order.status}")
      end
      item = @order.items.find_by(product_id: product&.id)

      return success_result(data: { item: item }, message: 'Found item') if item

      not_found_result(errors: ['Product not found in order'], message: 'Failed to remove product: product not found')
    end

    def mark_order_status(status)
      mark_status(:status, status, Order.statuses)
    end

    def mark_payment_status(status)
      mark_status(:payment_status, status, Order.payment_statuses)
    end

    def mark_status(attribute, status, valid_statuses)
      status_key = status.to_s
      unless valid_statuses.key?(status_key)
        return Services::Result.new(
          success?: false,
          errors: ["'#{status_key}' is not a valid #{attribute}."],
          status: :unprocessable_content,
          message: 'Invalid status provided.'
        )
      end

      if @order.update(attribute => status_key)
        Services::Result.new(
          success?: true,
          data: { order: @order },
          status: :ok,
          message: "Order #{attribute} successfully updated to '#{status_key}'."
        )
      else
        Services::Result.new(
          success?: false,
          errors: @order.errors.full_messages,
          status: :unprocessable_content,
          message: "Failed to update order #{attribute}."
        )
      end
    rescue StandardError => e
      Rails.logger.error("Failed to update #{attribute} for order #{@order.id}: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ["An unexpected error occurred while updating the order #{attribute}."],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end
  end
end
