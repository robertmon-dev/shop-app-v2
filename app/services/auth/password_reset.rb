# frozen_string_literal: true

module Services
  class PasswordResetService
    extend Concerns::ResultHelpers
    extend Concerns::Handlers

    def self.request(email)
      user = User.find_by(mail: email)
      if user
        code = SecureRandom.hex(4)
        expires_at = 2.hours.from_now

        redis_key = "password_reset:#{code}"
        begin
          Redis.current.with { |conn| conn.set(redis_key, user.id, ex: 2.hours.to_i) }
          UserMailer.dial_reset_code(user, code).deliver_later
        rescue Redis::CannotConnectError => e
          Rails.logger.error("Redis error during password reset request: #{e.message}")
          user.reset_code&.destroy
          user.create_reset_code!(code: code, expires_at: expires_at)
        end
      end

      Services::Result.new(
        success?: true,
        message: 'If an account exists, instructions have been sent to your email.',
        status: :ok
      )
    end

    def self.reset(code, password, password_confirmation)
      user = find_user_by_reset_code(code)

      unless user
        return Services::Result.new(
          success?: false,
          errors: ['Invalid or expired reset code.'],
          message: 'Invalid or expired password reset code.',
          status: :unprocessable_content
        )
      end

      unless password == password_confirmation
        return Services::Result.new(
          success?: false,
          errors: ['Password and confirmation do not match.'],
          message: 'Password and confirmation do not match.',
          status: :unprocessable_content
        )
      end

      if user.update(password: password, password_confirmation: password_confirmation)
        begin
          redis_key = "password_reset:#{code}"
          Redis.current.with { |conn| conn.del(redis_key) }
        rescue Redis::CannotConnectError => e
          Rails.logger.error("Redis error during password reset cleanup: #{e.message}")
        end
        user.reset_code&.destroy

        Services::Result.new(
          success?: true,
          message: 'Password has been reset successfully.',
          status: :ok
        )
      else
        Services::Result.new(
          success?: false,
          errors: user.errors.full_messages,
          message: 'Password reset failed due to validation errors.',
          status: :unprocessable_content
        )
      end
    rescue StandardError => e
      Rails.logger.error("Unexpected error during password reset for user ID #{user.id}: #{e.message}")
      Services::Result.new(
        success?: false,
        errors: ['An unexpected error occurred during password reset.'],
        message: 'An unexpected error occurred.',
        status: :internal_server_error
      )
    end

    def self.find_user_by_reset_code(code)
      user_id = nil
      begin
        user_id = Redis.current.with { |conn| conn.get("password_reset:#{code}") }
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error during password reset code lookup: #{e.message}")
      end

      if user_id
        user = User.find_by(id: user_id)
        return user
      else
        reset = ResetCode.find_by(code: code)
        return reset.user if reset&.expires_at&.future?
      end
      nil
    end
  end
end
