# frozen_string_literal: true

module Api
  module V1
    class CartController < Api::ApplicationController
      authorize_resource class: false

      def show = render_cart
      def add = render_cart(cart_service.add(params[:product_id], add_params[:quantity]))
      def revoke = render_cart(cart_service.remove(params[:item_id], revoke_params[:quantity_to_remove]))
      def clear = render_cart(cart_service.clear)

      private

      def cart_service
        @cart_service ||= Carts::Management.new(current_user)
      end

      def render_cart(result = nil)
        result ? bind_data(result) : reset_response_state
        assign(cart_service.cart_summary)

        render :show, status: @status, locals: { current_user: current_user }
      end

      def reset_response_state
        @status = :ok
        @errors = []
        @success = true
        @message = ''
      end

      def add_params = params.permit(:quantity)
      def revoke_params = params.permit(:quantity_to_remove)
    end
  end
end
