# frozen_string_literal: true

require 'twilio-ruby'

account_sid = ENV.fetch('TWILIO_ACCOUNT_SID')
auth_token  = ENV.fetch('TWILIO_AUTH_TOKEN')

if account_sid.present? && auth_token.present?
  TWILIO_CLIENT = Twilio::REST::Client.new(account_sid, auth_token)
  Rails.logger.info 'Twilio client initialized successfully.'
else
  Rails.logger.warn 'Twilio credentials not found. SMSService will not be available.'
end
