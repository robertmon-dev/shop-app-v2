# frozen_string_literal: true

namespace :rabbitmq do
  desc 'Consume order events from RabbitMQ'
  task consume: :environment do
    Rails.logger.info "Starting consumer on #{Services::ConsumerManager::QUEUE_NAME}"
    Services::ConsumerManager.start
  rescue Interrupt
    Services::ConsumerManager.stop
  end
end
