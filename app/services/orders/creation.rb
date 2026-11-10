# frozen_string_literal: true

module Services
  class OrderCreationService
    include Concerns::ResultHelpers
    include Concerns::Handlers

    def self.call(user:, package_carrier:, location_id:, cart_item_ids: [])
      new(user: user, package_carrier: package_carrier, location_id: location_id, cart_item_ids: cart_item_ids).call
    end

    def initialize(user:, package_carrier:, location_id:, cart_item_ids: [])
      @user = user
      @location_id = location_id
      @cart_item_ids = cart_item_ids
      @package_carrier = package_carrier
    end

    def call
      cart_items = find_cart_items
      return empty_cart_result if cart_items.empty?

      user_location = find_user_location
      return missing_location_result unless user_location

      process_order_creation(cart_items, user_location)
    end

    private

    def process_order_creation(cart_items, user_location)
      with_error_handling do
        order = nil
        ActiveRecord::Base.transaction do
          order = build_order(cart_items, user_location)
        end
        success_result(data: { order: order }, message: 'Order created successfully', status: :created)
      end
    end

    def build_order(cart_items, user_location)
      order_location = create_location_snapshot(user_location)
      order = @user.orders.build(location: order_location)
      order.package_carrier = @package_carrier if @package_carrier.present?

      order.items = cart_items
      order.save!
      Item.where(id: order.item_ids).update_all(user_id: nil)
      order
    end

    def create_location_snapshot(user_location)
      new_location = user_location.dup
      new_location.user_detail_id = nil
      new_location.save!
      new_location
    end

    def find_cart_items
      if @cart_item_ids.present?
        @user.cart_items.where(id: @cart_item_ids)
      else
        @user.cart_items
      end
    end

    def find_user_location
      locations = @user.user_detail&.locations
      return nil if locations.blank?

      @location_id.present? ? locations.find_by(id: @location_id) : locations.first
    end

    def empty_cart_result
      unprocessable_content_with_errors_result(errors: ['Your cart is empty or no items were selected.'],
                                               message: 'Your cart is empty or no items were selected.')
    end

    def missing_location_result
      unprocessable_content_with_errors_result(
        errors: ['A delivery location is required to create an order.'],
        message: 'A delivery location is required to create an order.'
      )
    end
  end
end
