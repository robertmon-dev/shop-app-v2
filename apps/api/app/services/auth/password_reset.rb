# frozen_string_literal: true

module Auth
  class PasswordReset < ApplicationService
    CODE_TTL = 2.hours

    class << self
      def request(email)
        user = User.find_by(mail: email)
        issue_code(user) if user
        success_result(message: 'If an account exists, instructions have been sent to your email.')
      end

      def reset(code, password, password_confirmation)
        user = find_user_by_reset_code(code)
        return invalid_code_response unless user
        return invalid_result('Password and confirmation do not match.') unless password == password_confirmation

        update_password(user, code, password, password_confirmation)
      rescue StandardError => e
        Rails.logger.error("Unexpected error during password reset: #{e.message}")
        internal_server_error_result(message: 'An unexpected error occurred.',
                                     errors: ['An unexpected error occurred during password reset.'])
      end

      def find_user_by_reset_code(code)
        user_id = redis_user_id(code)
        return User.find_by(id: user_id) if user_id

        reset = ResetCode.find_by(code: code)
        reset.user if reset&.expires_at&.future?
      end

      private

      def issue_code(user)
        code = SecureRandom.hex(8)
        store_code(user, code)
        UserMailer.dial_reset_code(user, code).deliver_later
      end

      def store_code(user, code)
        Redis.current.with { |conn| conn.set(redis_key(code), user.id, ex: CODE_TTL.to_i) }
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error during password reset request: #{e.message}")
        user.reset_code&.destroy
        user.create_reset_code!(code: code, expires_at: CODE_TTL.from_now)
      end

      def redis_user_id(code)
        Redis.current.with { |conn| conn.get(redis_key(code)) }
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error during password reset code lookup: #{e.message}")
        nil
      end

      def update_password(user, code, password, password_confirmation)
        unless user.update(password: password, password_confirmation: password_confirmation)
          return unprocessable_content_result(record: user, message: 'Password reset failed due to validation errors.')
        end

        clear_code(code)
        user.reset_code&.destroy
        success_result(message: 'Password has been reset successfully.')
      end

      def clear_code(code)
        Redis.current.with { |conn| conn.del(redis_key(code)) }
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error during password reset cleanup: #{e.message}")
      end

      def invalid_code_response
        invalid_result('Invalid or expired password reset code.', errors: ['Invalid or expired reset code.'])
      end

      def redis_key(code) = "password_reset:#{code}"
    end
  end
end
