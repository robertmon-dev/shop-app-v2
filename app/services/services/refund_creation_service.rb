# frozen_string_literal: true

module Services
  class RefundCreationService
    extend Concerns::Handlers
    extend Concerns::ResultHelpers

    REFUNDABLE_STATUSES = %w[delivered shipped].freeze

    def self.call(user:, order:, refund_params:)
      return not_found_result(errors: ['User not found'], message: 'User not found') unless user
      return not_found_result(errors: ['Order not found'], message: 'Order not found') unless order
      return not_refundable_result(order) unless refundable?(order)
      return already_requested_result(order) if order.refunds.where.not(status: :cancelled).exists?

      with_error_handling do
        refund = order.refunds.create!(refund_params.to_h.merge(user: user, refund_date: Time.current))

        success_result(data: { refund: refund }, message: 'Refund created successfully', status: :created)
      end
    end

    def self.refundable?(order)
      REFUNDABLE_STATUSES.include?(order.status) && order.payment_status_paid?
    end

    def self.not_refundable_result(order)
      unprocessable_content_with_errors_result(
        errors: ["Cannot refund an order with status: #{order.status} and payment status: #{order.payment_status}"],
        message: 'Order is not refundable.'
      )
    end

    def self.already_requested_result(order)
      conflict_result(errors: ['A refund has already been requested for this order.'],
                      message: "Order ##{order.id} already has a refund.")
    end

    private_class_method :refundable?, :not_refundable_result, :already_requested_result
  end
end
