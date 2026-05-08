# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  # Encapsulates diagnostic probes for application readiness and health.
  #
  # This service provides methods to check the operational status of key application
  # components, such as database connectivity and Redis availability. It's designed
  # for use in health check endpoints, providing insights into the application's
  # ability to serve requests.
  class DiagnosticsService
    # Performs a readiness probe for the application.
    #
    # A readiness probe checks if the application is ready to accept traffic.
    # It typically verifies critical dependencies like database connectivity.
    # If the database connection is established, the application is considered ready.
    #
    # @return [Hash] A hash containing the status and a message or errors.
    #   Returns `status: :ok` and a success message if ready.
    #   Returns `status: :service_unavailable` and errors if the check fails.
    def self.readiness_probe
      Services::Instrumentor.check_performed(:readiness)
      ActiveRecord::Base.connection.execute('SELECT 1')
      { status: :ok, message: 'Application is ready' }
    rescue StandardError => e
      { status: :service_unavailable, errors: ["Readiness check failed: #{e.message}"] }
    end

    # Performs a comprehensive health probe for the application.
    #
    # A health probe checks the overall health of the application and its critical
    # dependencies, including the database and Redis. It provides detailed status
    # for each checked component.
    #
    # @return [Hash] A hash containing the overall status, a message or errors, and component details.
    #   Returns `status: :ok` and a success message with details if all checks pass.
    #   Returns `status: :service_unavailable` with errors and details if any check fails.
    def self.health_probe
      Services::Instrumentor.check_performed(:health)

      db_ok, db_err = ping_database
      redis_ok, redis_err = ping_redis

      details = { db: db_ok, redis: redis_ok }
      errors = [db_err, redis_err]

      if errors.empty?
        { status: :ok, message: 'Application is healthy', details: details }
      else
        { status: :service_unavailable, errors: errors, details: details }
      end
    end

    def self.ping_database
      ActiveRecord::Base.connection.execute('SELECT 1')
      [true, nil]
    rescue StandardError => e
      [false, "Database check failed: #{e.message}"]
    end

    def self.ping_redis
      Redis.current.ping
      [true, nil]
    rescue Redis::CannotConnectError => e
      [false, "Redis check failed: #{e.message}"]
    end
  end
end
