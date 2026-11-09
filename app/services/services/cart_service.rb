# frozen_string_literal: true

module Services
  class CartService
    include Concerns::Handlers
    include Concerns::ResultHelpers

    def initialize(user)
      @user = user
    end

    def add(product_id, quantity)
      with_error_handling do
        product = Product.find_by(id: product_id)
        next not_found_result(errors: ['Product not found'], message: 'Product not found') unless product

        quantity = quantity.to_i
        next invalid_add_quantity_result unless quantity.positive?

        ActiveRecord::Base.transaction { process_cart(product, quantity) }
      end
    end

    def remove(item_id, quantity_to_remove = nil)
      with_error_handling do
        item = @user.cart_items.find_by(id: item_id)
        next item_not_found_result unless item

        quantity = quantity_to_remove&.to_i
        next invalid_remove_quantity_result if quantity && !quantity.positive?

        ActiveRecord::Base.transaction { perform_removal(item, quantity) }
      end
    end

    def clear
      with_error_handling do
        @user.cart_items.destroy_all
        @user.reload

        success_result(data: nil, message: 'Cart cleared successfully')
      end
    end

    def cart_summary
      cart_items = @user.cart_items.includes(:product)

      {
        cart_items: cart_items,
        total_amount: @user.cart_items.sum('quantity * price_at_purchase'),
        items_count: cart_items.sum(:quantity)
      }
    end

    private

    def process_cart(product, quantity)
      cart_item = @user.cart_items.find_or_initialize_by(product: product)
      cart_item.quantity = cart_item.new_record? ? quantity : cart_item.quantity + quantity
      cart_item.price_at_purchase = product.price
      cart_item.save!

      success_result(data: nil, message: 'Product added to cart successfully')
    end

    def perform_removal(item, quantity)
      if quantity.nil? || quantity >= item.quantity
        item.destroy!
        success_result(data: nil, message: 'Product removed from cart')
      else
        item.update!(quantity: item.quantity - quantity)
        success_result(data: nil, message: 'Product quantity updated in cart')
      end
    end

    def item_not_found_result
      not_found_result(errors: ['Product not in cart'], message: 'Product not in cart')
    end

    def invalid_add_quantity_result
      unprocessable_content_with_errors_result(errors: ['Quantity must be greater than 0'],
                                               message: 'Quantity must be greater than 0')
    end

    def invalid_remove_quantity_result
      unprocessable_content_with_errors_result(errors: ['Quantity to remove must be a positive number.'],
                                               message: 'Invalid quantity')
    end
  end
end
