# frozen_string_literal: true

require 'redis'
require 'connection_pool'

class Redis
  class << self
    attr_accessor :current

    def with(&)
      current.with(&)
    end
  end
end

redis_config = {}

if Rails.env.development? || Rails.env.test?
  redis_uri = URI.parse(ENV.fetch('REDIS_URL', 'redis://localhost:6379'))
  redis_config = {
    host: redis_uri.host,
    port: redis_uri.port,
    ssl: false
  }
elsif Rails.env.production?
  redis_config = {
    host: Rails.application.credentials.redis[:host],
    port: Rails.application.credentials.redis[:port],
    password: Rails.application.credentials.redis[:password],
    ssl: true
  }
end

Redis.current = ConnectionPool.new(size: 10, timeout: 5) do
  Redis.new(redis_config)
end
