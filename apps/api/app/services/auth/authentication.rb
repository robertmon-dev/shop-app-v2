# frozen_string_literal: true

module Auth
  class Authentication < ApplicationService
    TWO_FACTOR_TTL = 15.minutes

    class << self
      def login(email, password)
        user = User.find_by(mail: email)
        return authentication_failed('Invalid email or password.') unless user&.authenticate(password)
        return authentication_failed('User is not activated.') unless user.active?

        user.two_factor_enabled? ? start_two_factor(user) : issue_token(user, 'Logged in successfully.')
      rescue StandardError => e
        Rails.logger.error("Login process failed for email #{email}: #{e.message}")
        unexpected_error_result('An unexpected error occurred during login.')
      end

      def verify_2fa(user, code)
        return user_not_found_result unless user
        return invalid_two_factor_result if code.blank?
        return issue_token(user, '2FA verified successfully.') if redis_code_valid?(user, code)

        verify_2fa_with_database(user, code)
      rescue StandardError => e
        Rails.logger.error("2FA verification process failed for user #{user&.id}: #{e.message}")
        unexpected_error_result('An unexpected error occurred during 2FA verification.')
      end

      def resend_2fa_code(user)
        return user_not_found_result unless user

        send_2fa_code(user)
        success_result(message: 'Two-factor authentication code resent successfully')
      end

      def blacklist_token(token)
        Bearer.blacklist!(token)
      end

      private

      def start_two_factor(user)
        send_2fa_code(user)
        success_result(data: { user_id: user.id, two_factor_required: true }, status: :accepted,
                       message: 'Two-factor authentication code sent. Please verify.')
      end

      def issue_token(user, message)
        token_result = Bearer.encode({ user_id: user.id })
        return token_result unless token_result.success?

        success_result(data: { token: token_result.data[:token] }, message: message)
      end

      def verify_2fa_with_database(user, code)
        stored = user.second_factor_code
        return invalid_two_factor_result unless stored&.code == code && stored.expires_at&.future?

        stored.destroy
        issue_token(user, '2FA verified successfully via database.')
      end

      def redis_code_valid?(user, code)
        key = two_factor_key(user)
        return false unless Bearer.redis.with { |conn| conn.get(key) } == code

        Bearer.redis.with { |conn| conn.del(key) }
        user.second_factor_code&.destroy
        true
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error during 2FA verify for user #{user.id}: #{e.message}. Falling back to DB check.")
        false
      end

      def send_2fa_code(user)
        code = SecureRandom.hex(4)
        store_2fa_code(user, code)
        deliver_2fa_code(user, code)
      end

      def store_2fa_code(user, code)
        Bearer.redis.with { |conn| conn.set(two_factor_key(user), code, ex: TWO_FACTOR_TTL.to_i) }
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error during 2FA code send for user #{user.id}: #{e.message}. Falling back to DB.")
        user.second_factor_code&.destroy
        user.create_second_factor_code!(code: code, expires_at: TWO_FACTOR_TTL.from_now)
      rescue StandardError => e
        Rails.logger.error("Unexpected error creating 2FA code for user #{user.id}: #{e.message}")
      end

      def deliver_2fa_code(user, code)
        if user.phone.present?
          Notifications::Sms.dial_2fa_code(user, code)
        else
          UserMailer.dial_2fa_code(user, code).deliver_later
        end
      end

      def authentication_failed(error)
        unauthorized_result(errors: [error], message: 'Authentication failed.')
      end

      def invalid_two_factor_result
        unauthorized_result(errors: ['Invalid 2FA code.'], message: 'Invalid two-factor authentication code.')
      end

      def unexpected_error_result(error)
        internal_server_error_result(message: 'An unexpected error occurred.', errors: [error])
      end

      def two_factor_key(user) = "user:#{user.id}:2fa_code"
    end
  end
end
