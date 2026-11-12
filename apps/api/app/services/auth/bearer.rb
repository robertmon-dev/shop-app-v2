# frozen_string_literal: true

module Auth
  class Bearer < ApplicationService
    SECRET_KEY = Rails.application.credentials.secret_key_base
    TOKEN_LIFETIME = ENV.fetch('TOKEN_LIFETIME_HOURS', 24).to_i.hours.to_i
    KEY_PREFIX = 'jwt_status:'
    # Everything that means "Redis cannot answer right now": refused connection, timeout, exhausted pool.
    REDIS_UNAVAILABLE = [Redis::BaseConnectionError, ConnectionPool::TimeoutError].freeze

    def self.redis
      @redis ||= Redis.current
    end

    def self.encode(payload)
      with_error_handling do
        payload[:exp] = Time.now.to_i + TOKEN_LIFETIME
        token = JWT.encode(payload, SECRET_KEY, 'HS256')

        cache_token_with_fallback(token)

        success_result(data: { token: token }, message: 'Token encoded and cached successfully')
      end
    end

    def self.cache_token_with_fallback(token)
      redis.with { |conn| conn.set(cache_key(token), 'active', ex: TOKEN_LIFETIME) }
    rescue *REDIS_UNAVAILABLE => e
      Rails.logger.error "Redis error: Failed to cache JWT - #{e.message}. Token issued without Redis cache."
    end

    def self.blacklist_via_redis(token)
      redis.with { |conn| conn.set("jwt_status:#{token}", 'blacklisted', ex: TOKEN_LIFETIME) }
      success_result(data: nil, message: 'Token blacklisted successfully', status: :ok)
    end

    def self.blacklist_via_db(token, payload)
      BlacklistedToken.create!(
        token: token,
        owner_id: payload[:user_id],
        expires_at: Time.at(payload[:exp])
      )
      success_result(data: nil, message: 'Token blacklisted successfully', status: :ok)
    end

    def self.decode(token)
      status = blacklisted?(token)
      # Fail closed: if we cannot tell whether the token was revoked, we do not let it through.
      return status unless status.success?

      if status.data[:is_blacklisted]
        return unauthorized_result(errors: ['Token has been blacklisted'], message: 'Token blacklisted.')
      end

      decode_payload(token)
    end

    def self.blacklist!(token)
      decoded_result = decode_payload(token)
      unless decoded_result.success?
        return unprocessable_content_with_errors_result(
          errors: ['Invalid token for blacklisting'],
          message: 'Token could not be decoded for blacklisting'
        )
      end

      with_error_handling do
        with_redis_fallback(lambda {
          blacklist_via_db(token, decoded_result.data[:payload])
        }) { blacklist_via_redis(token) }
      end
    end

    def self.check_redis_blacklist(token)
      status = redis.with { |conn| conn.get("jwt_status:#{token}") }
      status == 'blacklisted'
    end

    def self.check_db_blacklist(token)
      BlacklistedToken.exists?(token: token)
    end

    def self.blacklisted?(token)
      is_blacklisted = begin
        check_redis_blacklist(token)
      rescue *REDIS_UNAVAILABLE
        check_db_blacklist(token)
      end

      success_result(data: { is_blacklisted: is_blacklisted }, message: build_message(is_blacklisted))
    rescue StandardError
      internal_server_error_result(errors: ['Failed to check blacklist  status.'],
                                   message: 'Blacklist check failed')
    end

    def self.build_message(is_blacklisted)
      is_blacklisted ? 'Token is blacklisted' : 'Token is not blacklisted'
    end

    def self.cache_key(token)
      "#{KEY_PREFIX}#{token}"
    end

    def self.decode_payload(token)
      with_jwt_error_handling do
        body = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })[0]
        payload = HashWithIndifferentAccess.new(body)
        success_result(data: { payload: payload }, message: 'Token decoded successfully', status: :ok)
      end
    end
  end
end
