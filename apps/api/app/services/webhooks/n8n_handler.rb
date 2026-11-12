# frozen_string_literal: true

module Webhooks
  class N8nHandler < ApplicationService
    EVENT_STATUSES = {
      'shipment.created' => :processing,
      'shipment.shipped' => :shipped,
      'shipment.delivered' => :delivered,
      'shipment.cancelled' => :cancelled
    }.freeze
    # Shipment events only ever move an order forward. Carriers' events may arrive out of order
    # or twice, so a stale one is acknowledged and ignored rather than rejected (n8n would retry it).
    PROGRESSION = %w[pending processing shipped delivered].freeze

    def self.call(payload) = new(payload).call

    def initialize(payload)
      @payload = normalize(payload)
    end

    def call
      return unknown_event_result unless EVENT_STATUSES.key?(event)

      order = Order.find_by(id: @payload[:order_id])
      return order_not_found_result unless order

      with_error_handling do
        EVENT_STATUSES.fetch(event) == :cancelled ? cancel(order) : advance(order)
      end
    end

    private

    def normalize(payload)
      case payload
      when String then JSON.parse(payload)
      when ActionController::Parameters then payload.to_unsafe_h
      else payload.to_h
      end.with_indifferent_access
    rescue JSON::ParserError
      {}.with_indifferent_access
    end

    def event = @payload[:event].to_s

    def advance(order)
      target = EVENT_STATUSES.fetch(event).to_s
      return locked_result(order) unless PROGRESSION.include?(order.status)
      return stale_result(order) unless advances?(order, target)

      order.update!(order_attributes)
      updated_result(order)
    end

    # Cancelling goes through Orders::Management so that a paid order is refunded.
    def cancel(order)
      return no_action_needed_result(message: "Order ##{order.id} is already cancelled.") if order.status_cancelled?

      cancelled = Orders::Management.new(order).cancel
      return cancelled unless cancelled.success?

      order.update!(order_attributes.except(:status))
      updated_result(order)
    end

    def updated_result(order)
      success_result(data: { order: order }, message: "Order ##{order.id} updated from #{event}")
    end

    def stale_result(order)
      no_action_needed_result(message: "Order ##{order.id} is already #{order.status}, ignoring #{event}.")
    end

    def advances?(order, target) = PROGRESSION.index(target) > PROGRESSION.index(order.status)

    def locked_result(order)
      message = "Order ##{order.id} is #{order.status} and can no longer change status."
      unprocessable_content_with_errors_result(errors: [message], message: message)
    end

    def order_attributes
      {
        status: EVENT_STATUSES.fetch(event),
        transaction_id: @payload[:tracking_id],
        shipping_service_id: @payload[:shipping_service_id],
        notes: @payload[:notes]
      }.compact
    end

    def unknown_event_result
      unprocessable_content_with_errors_result(
        errors: ["Unsupported event: #{event.presence || 'missing'}"],
        message: 'Unsupported n8n event.'
      )
    end

    def order_not_found_result
      not_found_result(errors: ['Order not found.'], message: "Order #{@payload[:order_id]} not found.")
    end
  end
end
