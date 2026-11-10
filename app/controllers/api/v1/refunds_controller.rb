# frozen_string_literal: true

module Api
  module V1
    class RefundsController < Api::ApplicationController
      load_and_authorize_resource :order, only: %i[create index]
      load_and_authorize_resource :refund, through: :order, only: %i[create index]
      load_and_authorize_resource :refund, except: %i[create index me]

      def index = respond_with_view(:index, refunds: accessible_refunds)
      def me = respond_with_view(:index, refunds: own_refunds)
      def show = respond_with_view(:show)
      def create = respond_with(Refunds::Creation.call(**create_args))
      def update = respond_with(Refunds::Update.call(@refund, update_refund_params))
      def destroy = respond_with_destroy(Refunds::Deletion.call(@refund))
      def cancel = respond_with(refund_management_service.cancel)
      def complete = respond_with(refund_management_service.complete)

      private

      def accessible_refunds
        Refund.accessible_by(current_ability).includes(:order).order(created_at: :desc)
      end

      def own_refunds = current_user.refunds.includes(:order).order(created_at: :desc)

      def create_args
        { user: current_user, order: @order, refund_params: refund_params }
      end

      def refund_management_service
        @refund_management_service ||= Refunds::Management.new(@refund)
      end

      def update_refund_params = params.require(:refund).permit(:status, :reason, :description)
      def refund_params = params.require(:refund).permit(:reason, :description)
    end
  end
end
