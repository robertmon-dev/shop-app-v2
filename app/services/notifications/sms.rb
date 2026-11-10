# frozen_string_literal: true

require 'twilio-ruby'

module Services
  class SmsService
    extend Concerns::Handlers

    class << self
      def dial(to:, body:)
        with_twilio_error_handling do
          return false if to.blank? || body.blank?
          return false unless twilio_available?

          msg = client.messages.create(
            from: from_number,
            to: to,
            body: body
          )
          Rails.logger.info("SMS sent successfully. SID=#{msg.sid}")
          true
        end
      end

      def dial_2fa_code(user, code)
        return false if user.phone.blank?

        dial(to: user.phone, body: "Your two-factor authentication code is: #{code}")
      end

      def dial_verification_code(user, code)
        return false if user.phone.blank?

        dial(to: user.phone, body: "Your verification code is #{code}")
      end

      private

      def client
        TWILIO_CLIENT
      end

      def from_number
        ENV.fetch('TWILIO_PHONE_NUMBER', {})
      end

      def twilio_available?
        if defined?(TWILIO_CLIENT) && TWILIO_CLIENT
          true
        else
          Rails.logger.warn('Twilio client is not available')
          false
        end
      end
    end
  end
end
