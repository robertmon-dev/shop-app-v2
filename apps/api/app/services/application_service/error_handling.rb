# frozen_string_literal: true

class ApplicationService
  module ErrorHandling
    def with_error_handling(_context = nil)
      yield
    rescue StandardError => e
      error_result_for(e)
    end

    def with_error_not_destroyed_handling
      yield
    rescue ActiveRecord::RecordNotFound
      not_found_result(errors: ['Record hasnt been found'], message: 'Failed to find such record')
    rescue ActiveRecord::RecordNotDestroyed => e
      record_not_destroyed_error_result(exc: e, record: e.record)
    rescue StandardError => e
      error_result_for(e)
    end

    def with_stripe_error_handling
      yield
    rescue Stripe::StripeError => e
      stripe_error_result(e)
    rescue StandardError => e
      error_result_for(e)
    end

    def with_json_parser_error_handling
      yield
    rescue JSON::ParserError
      json_parser_error_result(errors: ['Invalid webhook payload'], message: 'Invalid payload')
    rescue Stripe::SignatureVerificationError
      stripe_verification_error_result(errors: ['Stripe signature verification failed.'],
                                       message: 'Signature verification failed')
    rescue StandardError => e
      error_result_for(e)
    end

    def with_webhook_error_handling
      yield
    rescue StandardError => e
      Rails.logger.error("Webhook: Error processing Stripe event. #{e.message}")
      failure_result(status: :internal_server_error, errors: [], message: 'Webhook processing failed.')
    end

    def with_jwt_error_handling
      yield
    rescue JWT::ExpiredSignature
      unauthorized_result(errors: ['Token has expired.'], message: 'Token expired')
    rescue JWT::DecodeError
      unauthorized_result(errors: ['Invalid token.'], message: 'Invalid token')
    rescue StandardError
      internal_server_error_result(message: 'Decoding failed.',
                                   errors: ['An unexpected error occurred during token decoding'])
    end

    def with_additional_redis_error_handling
      yield
    rescue StandardError
      internal_server_error_result(message: 'Failed to encode token.', errors: ['Token encoding failed.'])
    end

    def with_redis_error_handling
      yield
    rescue Redis::CannotConnectError => e
      Rails.logger.error("Redis error falling back to DB: #{e.message}")
    end

    def with_redis_fallback(fallback)
      yield
    rescue Redis::BaseConnectionError, ConnectionPool::TimeoutError => e
      Rails.logger.error("Redis error, falling back to DB: #{e.message}")
      fallback.call
    end

    def with_twilio_error_handling
      yield
    rescue StandardError => e
      Rails.logger.error("Twilio Error: Failed to send SMS: #{e.message}")
      false
    end

    private

    def error_result_for(exc)
      case exc
      when ActiveRecord::RecordNotFound then user_not_found_result
      when ActiveRecord::RecordInvalid then invalid_record_result(exc)
      else unknown_error_result(exc)
      end
    end
  end
end
