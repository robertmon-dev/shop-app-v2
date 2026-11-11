# frozen_string_literal: true

module Diagnostics
  class Probe
    def self.readiness_probe
      Diagnostics::Instrumentor.check_performed(:readiness)
      ActiveRecord::Base.connection.execute('SELECT 1')

      { status: :ok, message: 'Application is ready' }
    rescue StandardError => e
      { status: :service_unavailable, errors: ["Readiness check failed: #{e.message}"] }
    end

    def self.health_probe
      Diagnostics::Instrumentor.check_performed(:health)

      database_ok, database_error = ping_database
      redis_ok, redis_error = ping_redis

      details = { database: database_ok, redis: redis_ok }
      errors = [database_error, redis_error].compact

      return { status: :ok, message: 'Application is healthy', details: details } if errors.empty?

      { status: :service_unavailable, errors: errors, details: details }
    end

    def self.ping_database
      ActiveRecord::Base.connection.execute('SELECT 1')
      [true, nil]
    rescue StandardError => e
      [false, "Database check failed: #{e.message}"]
    end

    def self.ping_redis
      Redis.with(&:ping)
      [true, nil]
    rescue StandardError => e
      [false, "Redis check failed: #{e.message}"]
    end
  end
end
