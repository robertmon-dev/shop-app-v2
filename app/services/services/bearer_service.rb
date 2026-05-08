# frozen_string_literal: true

# Provides a collection of service objects that encapsulate specific business logic
# or external integrations.
#
# This module aims to keep controllers thin and models focused on data persistence
# by housing operations that don't fit naturally within a single model's scope
# or represent a cross-cutting concern. Examples include authentication flows,
# payment processing, or external API interactions
module Services
  # Handles JWT (JSON Web Token) encoding, decoding, and blacklisting operations.
  #
  # This service provides a centralized way to manage authentication tokens,
  # including setting their lifetime, interacting with Redis for token status
  # (active/blacklisted), and handling JWT-related errors.
  class BearerService
    extend Concerns::ResultHelpers
    extend Concerns::Handlers

    SECRET_KEY = Rails.application.credentials.secret_key_base
    TOKEN_LIFETIME = 24.hours.to_i
    KEY_PREFIX = 'jwt_status:'

    def self.redis
      @redis ||= Redis.current
    end

    # Encodes a payload into a JWT token and caches its active status.
    #
    # @param payload [Hash] The data to be encoded in the token (e.g., {user_id: 1}).
    # @return [Services::Result] A Result object indicating success or failure,
    #   containing the token on success or errors on failure.
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
    rescue Redis::CannotConnectError => e
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

    # Decodes a JWT token. Checks if the token is blacklisted before decoding.
    #
    # @param token [String] The JWT token to decode.
    # @return [Services::Result] A Result object containing the decoded payload on success,
    #   or errors if the token is invalid, expired, or blacklisted.
    def self.decode(token)
      if blacklisted?(token).success? && blacklisted?(token).data[:is_blacklisted]
        return unauthorized_result(errors: ['Token has been blacklisted'], message: 'Token blacklisted.')
      end

      decode_payload(token)
    end

    # Blacklists a JWT token.
    #
    # @param token [String] The JWT token to blacklist.
    # @return [Services::Result] A Result object indicating success or failure of blacklisting.
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

    # Checks if a token is blacklisted.
    #
    # @param token [String] The JWT token to check.
    # @return [Services::Result] A Result object indicating if the token is blacklisted
    #   and the status of the check (e.g., :ok, :internal_server_error).
    def self.blacklisted?(token)
      is_blacklisted = begin
        check_redis_blacklist(token)
      rescue Redis::CannotConnectError
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

    # Decodes the JWT token payload.
    #
    # @param token [String] The JWT token to decode.
    # @return [Services::Result] A Result object containing the decoded payload on success,
    #   or errors if the token is invalid or expired.
    def self.decode_payload(token)
      with_jwt_error_handling do
        body = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })[0]
        payload = HashWithIndifferentAccess.new(body)
        success_result(data: { payload: payload }, message: 'Token decoded successfully', status: :ok)
      end
    end
  end
end
