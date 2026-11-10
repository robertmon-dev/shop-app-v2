# frozen_string_literal: true

module Services
  class OrderManagementService
    include Concerns::Handlers
    include Concerns::ResultHelpers

    def initialize(order)
      @order = order
    end

    def update(params)
      with_error_handling do
        if @order.update(params)
          success_result(data: { order: @order.reload }, message: 'Order updated successfully')
        else
          unprocessable_content_result(record: @order, message: 'Order update failed due to validation errors.')
        end
      end
    end

    def cancel
      return cannot_cancel_result unless modifiable?

      with_error_handling do
        if @order.update(status: :cancelled)
          success_result(data: { order: @order }, message: 'Order cancelled successfully')
        else
          unprocessable_content_result(record: @order, message: 'Order cancellation failed due to validation errors.')
        end
      end
    end

    def destroy
      with_error_not_destroyed_handling do
        @order.destroy!
        destroy_success_result(message: 'Successfully destroyed order')
      end
    end

    def add_product(product, quantity)
      quantity = quantity.to_i
      return invalid_input_result unless product && quantity.positive?
      return cannot_modify_result unless modifiable?

      with_error_handling do
        ActiveRecord::Base.transaction do
          item = @order.items.find_or_initialize_by(product_id: product.id)
          item.price_at_purchase ||= product.price
          item.quantity = item.new_record? ? quantity : item.quantity + quantity
          item.save!
          @order.save!
        end

        success_result(data: { order: @order.reload }, message: 'Product added to order successfully')
      end
    end

    def remove_product(product, quantity = nil)
      item = @order.items.find_by(product_id: product&.id)
      return product_not_in_order_result unless item
      return cannot_modify_result unless modifiable?

      with_error_not_destroyed_handling do
        quantity.nil? ? destroy_item(item) : decrement_item(item, quantity.to_i)
      end
    end

    def mark_order_status(status)
      mark_status(:status, status, Order.statuses)
    end

    def mark_payment_status(status)
      mark_status(:payment_status, status, Order.payment_statuses)
    end

    private

    def mark_status(attribute, status, valid_statuses)
      status_key = status.to_s
      return invalid_status_result(attribute, status_key) unless valid_statuses.key?(status_key)

      with_error_handling do
        if @order.update(attribute => status_key)
          success_result(data: { order: @order },
                         message: "Order #{attribute} successfully updated to '#{status_key}'.")
        else
          unprocessable_content_result(record: @order, message: "Failed to update order #{attribute}.")
        end
      end
    end

    def destroy_item(item)
      item.destroy!
      @order.items.reload

      success_result(data: { order: @order.reload }, message: 'Product removed from order successfully')
    end

    def decrement_item(item, quantity)
      invalid = invalid_removal_quantity(item, quantity)
      return invalid if invalid
      return destroy_item(item) if quantity >= item.quantity

      item.update!(quantity: item.quantity - quantity)
      @order.items.reload

      success_result(data: { order: @order.reload }, message: 'Product quantity decreased successfully')
    end

    def invalid_removal_quantity(item, quantity)
      unless quantity.positive?
        return unprocessable_content_with_errors_result(errors: ['Quantity must be a positive number.'],
                                                        message: 'Invalid quantity')
      end
      return unless quantity > item.quantity

      unprocessable_content_with_errors_result(
        errors: ["Cannot remove #{quantity} items, only #{item.quantity} present."],
        message: 'Invalid quantity'
      )
    end

    def modifiable?
      @order.status_pending? || @order.status_processing?
    end

    def invalid_input_result
      unprocessable_content_with_errors_result(errors: ['Invalid product or quantity.'],
                                               message: 'Failed to add product: invalid input.')
    end

    def cannot_modify_result
      unprocessable_content_with_errors_result(errors: ["Cannot modify order with status: #{@order.status}"],
                                               message: "Cannot modify order with status: #{@order.status}")
    end

    def cannot_cancel_result
      unprocessable_content_with_errors_result(errors: ["Cannot cancel order with status: #{@order.status}"],
                                               message: "Cannot cancel order with status: #{@order.status}")
    end

    def product_not_in_order_result
      not_found_result(errors: ['Product not found in order.'],
                       message: 'Failed to remove product: product not found')
    end

    def invalid_status_result(attribute, status_key)
      unprocessable_content_with_errors_result(errors: ["'#{status_key}' is not a valid #{attribute}."],
                                               message: 'Invalid status provided.')
    end
  end
end
