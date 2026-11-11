# frozen_string_literal: true

module Api
  module V1
    class OrdersController < Api::ApplicationController
      before_action :set_order, only: %i[add_product remove_product mark_order_status mark_payment_status cancel]
      before_action :set_product, only: %i[add_product remove_product]
      load_and_authorize_resource except: %i[me create add_product remove_product cancel mark_order_status
                                             mark_payment_status]

      def index = respond_with_view(:index, orders: accessible_orders)
      def me = respond_with_view(:index, orders: own_orders)
      def show = respond_with_view(:show)
      def create = respond_with(Orders::Creation.call(**create_args))
      def update = respond_with(order_management_service.update(update_order_params))
      def cancel = respond_with(order_management_service.cancel)
      def destroy = respond_with_destroy(order_management_service.destroy)
      def add_product = respond_with(order_management_service.add_product(@product, added_quantity))
      def remove_product = respond_with(order_management_service.remove_product(@product, removed_quantity))
      def mark_order_status = respond_with(order_management_service.mark_order_status(order_status_params[:status]))

      def mark_payment_status
        respond_with(order_management_service.mark_payment_status(payment_status_params[:payment_status]))
      end

      private

      def accessible_orders
        Order.accessible_by(current_ability).includes(:user, :items).order(created_at: :desc)
      end

      def own_orders = current_user.orders.includes(:items).order(created_at: :desc)

      def create_args
        { user: current_user, cart_item_ids: order_params[:cart_item_ids],
          package_carrier: order_params[:package_carrier], location_id: order_params[:location_id] }
      end

      def order_management_service
        @order_management_service ||= Orders::Management.new(@order)
      end

      def set_order
        @order = Order.find_by(id: params[:id])
        return render_failure(message: 'Order not found.', status: :not_found) unless @order

        authorize! action_name.to_sym, @order
      end

      def set_product
        product_id = params[:product_id] || add_product_params[:product_id]
        @product = Product.find_by(id: product_id)
        render_failure(message: 'Product not found.', status: :not_found) unless @product
      end

      def added_quantity = add_product_params[:quantity].to_i
      def removed_quantity = remove_product_params[:quantity]

      def update_order_params
        params.require(:order).permit(:status, :payment_status, :package_carrier, :package_type, :notes)
      end

      def order_params
        params.fetch(:order, {}).permit(:package_carrier, :location_id, cart_item_ids: [])
      end

      def add_product_params = params.require(:order).permit(:product_id, :quantity)
      def remove_product_params = params.permit(:product_id, :quantity)
      def order_status_params = params.require(:order).permit(:status)
      def payment_status_params = params.require(:order).permit(:payment_status)
    end
  end
end
