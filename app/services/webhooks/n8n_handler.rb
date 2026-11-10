# frozen_string_literal: true

module Webhooks
  class N8nHandler < ApplicationService
    EVENT_STATUSES = {
      'shipment.created' => :processing,
      'shipment.shipped' => :shipped,
      'shipment.delivered' => :delivered,
      'shipment.cancelled' => :cancelled
    }.freeze

    def self.call(payload) = new(payload).call

    def initialize(payload)
      @payload = normalize(payload)
    end

    def call
      return unknown_event_result unless EVENT_STATUSES.key?(event)

      order = Order.find_by(id: @payload[:order_id])
      return order_not_found_result unless order

      with_error_handling do
        order.update!(order_attributes)

        success_result(data: { order: order }, message: "Order ##{order.id} updated from #{event}")
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
