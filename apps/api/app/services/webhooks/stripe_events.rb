# frozen_string_literal: true

module Webhooks
  class StripeEvents < ApplicationService
    def self.handle(event)
      with_webhook_error_handling do
        dispatch_event(event)
      end
    end

    def self.dispatch_event(event)
      case event.type
      when 'payment_intent.succeeded'
        handle_payment_intent_succeeded(event.data.object)
      when 'payment_intent.payment_failed'
        handle_payment_intent_failed(event.data.object)
      when 'charge.refunded'
        handle_charge_refunded(event.data.object)
      else
        no_action_needed_result(message: "Unhandled event type: #{event.type}")
      end
    end

    def self.handle_payment_intent_succeeded(payment_intent)
      with_error_handling do
        order = Order.find_by(stripe_payment_intent_id: payment_intent.id)

        unless order
          Rails.logger.error("Webhook Error: Could not find Order for succeeded PI #{payment_intent.id}")
          return not_found_result(errors: ['Order not found for PI'], message: 'Order not found for PI')
        end

        if order.payment_status_paid?
          return no_action_needed_result(message: "Order ##{order.id} is already marked as paid.")
        end

        return amount_mismatch_result(order, payment_intent) unless amount_matches?(order, payment_intent)

        ActiveRecord::Base.transaction do
          Payment.create_from_payment_intent(payment_intent)
          order.mark_as_paid!
        end

        log_and_return_success_result("Successfully processed payment for Order ##{order.id}.")
      end
    end

    def self.handle_payment_intent_failed(payment_intent)
      order = Order.find_by(stripe_payment_intent_id: payment_intent.id)
      return no_action_needed_result(message: "Order not found for failed PI #{payment_intent.id}") unless order

      if order.payment_status_paid? || order.payment_status_refunded?
        return no_action_needed_result(message: "Order ##{order.id} is #{order.payment_status}, ignoring failure.")
      end

      order.mark_as_failed!
      log_and_return_success_result("Marked Order ##{order.id} as failed.")
    end

    def self.handle_charge_refunded(charge)
      payment = Payment.find_by(stripe_charge_id: charge.id)
      return no_action_needed_result(message: "Payment not found for refunded Charge #{charge.id}") unless payment
      return no_action_needed_result(message: "Payment ##{payment.id} already refunded.") if payment.status_refunded?
      unless fully_refunded?(charge)
        return no_action_needed_result(message: "Charge #{charge.id} was only partially refunded.")
      end

      ActiveRecord::Base.transaction do
        payment.mark_as_refunded!
        payment.order.mark_as_refunded!
        settle_open_refunds(payment)
      end

      log_and_return_success_result("Processed refund for Payment ##{payment.id}.")
    end

    def self.fully_refunded?(charge)
      charge.amount_refunded.to_i >= charge.amount.to_i
    end

    def self.amount_matches?(order, payment_intent)
      payment_intent.amount_received.to_i == order.total_in_cents
    end

    def self.amount_mismatch_result(order, payment_intent)
      message = "Received #{payment_intent.amount_received} for Order ##{order.id}, expected #{order.total_in_cents}."
      Rails.logger.error("Webhook Error: #{message}")
      unprocessable_content_with_errors_result(errors: [message], message: 'Payment amount does not match the order.')
    end

    def self.settle_open_refunds(payment)
      payment.order.refunds.where(status: %i[pending processing])
             .update_all(status: Refund.statuses[:refunded], payment_status: Refund.payment_statuses[:refunded],
                         payment_id: payment.id, updated_at: Time.current)
    end
  end
end
