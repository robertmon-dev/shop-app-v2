# frozen_string_literal: true

module Users
  class Management < ApplicationService
    extend CodeValidation

    def self.activate(user, code)
      return user_not_found_result unless user
      return user_already_activated_result unless user.unactivated?

      with_error_handling do
        validate_and_execute_code(user.activation_code, code, 'activation') do
          user.update!(active: true)
          user.create_verification_code!(code: SecureRandom.hex(16))
          success_result(data: { user: user }, message: 'Account activated successfully.')
        end
      end
    end

    def self.verify(user, code)
      return user_not_found_result unless user
      return user_already_verified_result unless user.unverified?

      with_error_handling do
        validate_and_execute_code(user.verification_code, code, 'verification') do
          user.update!(verified: true)
          success_result(data: { user: user }, message: 'Account verified successfully.')
        end
      end
    end

    def self.resend_activation_code(user)
      return user_not_found_result unless user
      return user_already_activated_result unless user.unactivated?

      with_error_handling do
        UserMailer.dial_activation_code(user, user.activation_code.code).deliver_later
        success_result(data: { user: user }, message: 'Activation code resent successfully')
      end
    end

    def self.resend_verification_code(user)
      return user_not_found_result unless user
      return user_already_verified_result unless user.unverified?

      with_error_handling do
        Notifications::Sms.dial_verification_code(user, user.verification_code.code)
        success_result(data: { user: user }, message: 'Verification code resent successfully')
      end
    end

    def self.blacklist_user(id:) = set_blacklisted(id, true)
    def self.whitelist_user(id:) = set_blacklisted(id, false)

    def self.set_blacklisted(id, value)
      with_error_handling do
        user = User.find(id)
        user.update!(blacklisted: value)
        success_result(data: { user: user }, message: "User #{value ? 'blacklisted' : 'whitelisted'} successfully")
      end
    end
    private_class_method :set_blacklisted
  end
end
