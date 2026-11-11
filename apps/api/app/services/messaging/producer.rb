# frozen_string_literal: true

require 'bunny'

module Messaging
  class Producer
    TOPIC_NAME = ENV.fetch('RABBIT_TOPIC', 'orders.events')

    class << self
      def produce(payload)
        exchange = channel.fanout(TOPIC_NAME, durable: true)
        exchange.publish(payload.to_json, persistent: true, content_type: 'application/json')
        Rails.logger.info "Successfully published message for topic: #{TOPIC_NAME}"
      rescue StandardError => e
        Rails.logger.error "Failed to publish message on topic: #{TOPIC_NAME}, #{e.message}"
      end

      private

      def close
        @connection&.close
      end

      def connection
        return @connection if @connection&.open?

        @connection = Bunny.new(config)
        @connection.start
        @connection
      end

      def config
        RABBIT_CONFIG
      end

      def channel
        @channel ||= connection.create_channel
      end

      def credentials
        Rails.application.credentials.rabbit_mq || {}
      end
    end
  end
end
