# frozen_string_literal: true

require 'bunny'

module Services
  class ConsumerManager
    QUEUE_NAME = ENV.fetch('RABBIT_CONSUMER_QUEUE', 'orders.events.shop')
    HANDLERS = { 'shipment' => Services::N8nWebhookHandler }.freeze

    class << self
      def start(blocking: true)
        bind_queue.subscribe(manual_ack: true, block: blocking) do |delivery_info, _properties, body|
          process(body)
          channel.ack(delivery_info.delivery_tag)
        rescue StandardError => e
          Rails.logger.error "ConsumerManager: rejecting message - #{e.message}"
          channel.reject(delivery_info.delivery_tag, false)
        end
      end

      def process(body)
        payload = JSON.parse(body)
        handler = HANDLERS[payload['domain'].to_s] || Services::N8nWebhookHandler
        result = handler.call(payload)

        return Rails.logger.info "ConsumerManager: #{result.message}" if result.success?

        Rails.logger.error "ConsumerManager: #{result.errors.join(', ')}"
        result
      rescue JSON::ParserError => e
        Rails.logger.error "ConsumerManager: invalid payload - #{e.message}"
        nil
      end

      def stop
        @channel&.close
        @connection&.close
        @channel = nil
        @connection = nil
      end

      private

      def bind_queue
        exchange = channel.fanout(Services::Producer::TOPIC_NAME, durable: true)
        channel.queue(QUEUE_NAME, durable: true).bind(exchange)
      end

      def channel
        @channel ||= connection.create_channel
      end

      def connection
        return @connection if @connection&.open?

        @connection = Bunny.new(RABBIT_CONFIG)
        @connection.start
        @connection
      end
    end
  end
end
