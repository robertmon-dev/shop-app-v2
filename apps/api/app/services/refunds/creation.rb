# frozen_string_literal: true

module Refunds
  class Creation < ApplicationService
    REFUNDABLE_STATUSES = %w[delivered shipped].freeze

    def initialize(user:, order:, refund_params:)
      @user = user
      @order = order
      @refund_params = refund_params
    end

    def call
      return missing_result('User') unless @user
      return missing_result('Order') unless @order
      return not_refundable_result unless refundable?
      return already_requested_result if @order.refunds.where.not(status: :cancelled).exists?

      with_error_handling do
        refund = @order.refunds.create!(@refund_params.to_h.merge(user: @user, refund_date: Time.current))
        success_result(data: { refund: refund }, message: 'Refund created successfully', status: :created)
      end
    end

    private

    def refundable?
      REFUNDABLE_STATUSES.include?(@order.status) && @order.payment_status_paid?
    end

    def not_refundable_result
      invalid_result(
        'Order is not refundable.',
        errors: ["Cannot refund an order with status: #{@order.status} and payment status: #{@order.payment_status}"]
      )
    end

    def already_requested_result
      conflict_result(errors: ['A refund has already been requested for this order.'],
                      message: "Order ##{@order.id} already has a refund.")
    end
  end
end
