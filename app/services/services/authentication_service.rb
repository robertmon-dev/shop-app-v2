# frozen_string_literal: true

module Services
  class AuthenticationService
    def self.login(email, password)
      user = User.find_by(mail: email)
      unless user&.active?
        return Result.new(
          success?: false,
          errors: ['User is not activated.'],
          status: :unauthorized,
          message: 'Authentication failed.'
        )
      end

      unless user&.authenticate(password)
        return Result.new(
          success?: false,
          errors: ['Invalid email or password.'],
          status: :unauthorized,
          message: 'Authentication failed.'
        )
      end

      if user.two_factor_enabled?
        send_2fa_code(user)
        Result.new(
          success?: true,
          message: 'Two-factor authentication code sent. Please verify.',
          status: :accepted,
          data: { user_id: user.id, two_factor_required: true }
        )
      else
        token_result = BearerService.encode({ user_id: user.id })
        if token_result.success?
          Result.new(
            success?: true,
            data: { token: token_result.data[:token] },
            status: :ok,
            message: 'Logged in successfully.'
          )
        else
          token_result
        end
      end
    rescue StandardError => e
      Rails.logger.error("Login process failed for email #{email}: #{e.message}")
      Result.new(
        success?: false,
        errors: ['An unexpected error occurred during login.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end

    def self.verify_2fa(user, code)
      return user_not_found_result unless user

      redis_key = "user:#{user.id}:2fa_code"

      begin
        if BearerService.redis.with { |conn| conn.get(redis_key) } == code
          BearerService.redis.with { |conn| conn.del(redis_key) }
          user.second_factor_code&.destroy
          token_result = BearerService.encode({ user_id: user.id })
          return Result.new(
            success?: true,
            data: { token: token_result.data[:token] },
            status: :ok,
            message: '2FA verified successfully.'
          )
        end
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error during 2FA verify for user #{user.id}: #{e.message}. Falling back to DB check.")
      end

      if user.second_factor_code&.code == code
        user.second_factor_code.destroy
        token_result = BearerService.encode({ user_id: user.id })
        return Result.new(
          success?: true,
          data: { token: token_result.data[:token] },
          status: :ok,
          message: '2FA verified successfully via database.'
        )
      end

      Result.new(
        success?: false,
        errors: ['Invalid 2FA code.'],
        status: :unauthorized,
        message: 'Invalid two-factor authentication code.'
      )
    rescue StandardError => e
      Rails.logger.error("2FA verification process failed for user #{user.id}: #{e.message}")
      Result.new(
        success?: false,
        errors: ['An unexpected error occurred during 2FA verification.'],
        status: :internal_server_error,
        message: 'An unexpected error occurred.'
      )
    end

    def self.blacklist_token(token)
      BearerService.blacklist!(token)
    end

    private

    def self.send_2fa_code(user)
      return user_not_found_result unless user

      code = SecureRandom.hex(4)
      redis_key = "user:#{user.id}:2fa_code"
      expires_at = 15.minutes.from_now

      begin
        BearerService.redis.with { |conn| conn.set(redis_key, code, ex: 15.minutes.to_i) }
      rescue Redis::CannotConnectError => e
        Rails.logger.error("Redis error during 2FA code send for user #{user.id}: #{e.message}. Falling back to DB.")
        user.second_factor_code&.destroy
        user.create_second_factor_code!(code: code, expires_at: expires_at)
      rescue StandardError => e
        Rails.logger.error("Unexpected error creating 2FA code for user #{user.id}: #{e.message}")
      end

      if user.phone.present?
        SmsService.dial_2fa_code(user, code)
      else
        UserMailer.dial_2fa_code(user, code).deliver_later
      end
    end

    def self.user_not_found_result
      Services::Result.new(
        success?: false,
        errors: ['user not found.'],
        status: :not_found,
        message: 'user not found.'
      )
    end
    private_class_method :send_2fa_code, :user_not_found_result
  end
end
