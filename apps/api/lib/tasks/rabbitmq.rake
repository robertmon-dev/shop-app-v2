# frozen_string_literal: true

namespace :rabbitmq do
  desc 'Consume order events from RabbitMQ'
  task consume: :environment do
    Rails.logger.info "Starting consumer on #{Messaging::ConsumerManager::QUEUE_NAME}"
    Messaging::ConsumerManager.start
  rescue Interrupt
    Messaging::ConsumerManager.stop
  end
end
