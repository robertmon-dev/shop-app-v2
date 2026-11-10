# frozen_string_literal: true

module Api
  module V1
    class PaymentsController < Api::ApplicationController
      load_and_authorize_resource except: [:create]

      def index = respond_with_view(:index, payments: payments_scope)
      def show = respond_with_view(:show)
      def create = respond_with(Payments::Creation.call(user: current_user, order_id: order_id))

      private

      def payments_scope = Payment.includes(:order).order(created_at: :desc)
      def order_id = payment_params[:order_id]
      def payment_params = params.require(:payment).permit(:order_id)
    end
  end
end
