# frozen_string_literal: true

module Payments
  class Creation < ApplicationService
    class << self
      def call(user:, order_id:)
        validate_and_find_order(user: user, order_id: order_id).then { |order| create_or_update_payment_intent(order) }
      end

      def validate_and_find_order(user:, order_id:)
        order = user.orders.find_by(id: order_id)

        unless order
          return not_found_result(errors: ['Order not found or does not belong to the user.'],
                                  message: 'Order not found or does not belong to the user.')
        end

        unless order.status_pending? || order.status_processing?
          return unprocessable_content_with_errors_result(
            errors: ["Cannot pay for an order with status: #{order.status}."],
            message: "Cannot pay for an order with status: #{order.status}."
          )
        end

        if order.payment_status_paid?
          return unprocessable_content_with_errors_result(errors: ['This order has already been paid for.'],
                                                          message: 'This order has already been paid for.')
        end

        success_result(data: order, message: 'order validated successfully')
      end

      def create_or_update_payment_intent(order)
        with_stripe_error_handling do
          payment_intent = if order.stripe_payment_intent_id
                             update_payment_intent(order)
                           else
                             create_payment_intent!(order)
                           end

          success_result(data: { client_secret: payment_intent.client_secret },
                         message: 'Payment intent created successfully.')
        end
      end

      def sync_amount(order)
        return if order.stripe_payment_intent_id.blank? || order.payment_status_paid?

        update_payment_intent(order.reload)
      rescue Stripe::StripeError => e
        Rails.logger.warn("Could not sync PaymentIntent for Order ##{order.id}: #{e.message}")
      end

      def update_payment_intent(order)
        Stripe::PaymentIntent.update(
          order.stripe_payment_intent_id,
          amount: order.total_in_cents,
          currency: 'pln'
        )
      end

      def create_payment_intent!(order)
        payment_intent = Stripe::PaymentIntent.create(
          amount: order.total_in_cents,
          currency: 'pln',
          metadata: { order_id: order.id }
        )
        order.update!(stripe_payment_intent_id: payment_intent.id)
        payment_intent
      end
    end
  end
end
