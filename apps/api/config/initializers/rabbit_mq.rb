# frozen_string_literal: true

RABBIT_CONFIG = {
  host: ENV.fetch('RABBITMQ_DEFAULT_HOST', '127.0.0.1'),
  port: ENV.fetch('RABBITMQ_DEFAULT_PORT', 5672).to_i,
  vhost: ENV.fetch('RABBITMQ_DEFAULT_VHOST', '/'),
  user: ENV.fetch('RABBITMQ_DEFAULT_USER', 'guest'),
  password: ENV.fetch('RABBITMQ_DEFAULT_PASS', 'guest'),
  heartbeat: ENV.fetch('RABBITMQ_HEARTBEAT', 5).to_i,
  frame_max: ENV.fetch('RABBITMQ_FRAME_MAX', 131_072).to_i,
  auth_mechanism: ENV.fetch('RABBITMQ_AUTH_MECHANISM', 'PLAIN')
}.freeze
