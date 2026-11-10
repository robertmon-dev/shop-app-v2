# frozen_string_literal: true

require 'rails_helper'
require 'twilio-ruby'

RSpec.describe Services::SmsService, type: :service do
  let!(:user) { create(:user, phone: '+15005550006') }
  let(:twilio_credentials) do
    {
      account_sid: 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
      auth_token: 'your_auth_token',
      phone_number: '+15005550001'
    }
  end

  let(:twilio_client) { double('Twilio REST Client') }
  let(:messages_proxy) { double('Twilio Messages Proxy') }
  let(:twilio_message) { double('Twilio Message', sid: 'SMxxxxxxxxxxxxxxxxxxxxxxxxxxxxx') }

  module Twilio; module REST; class TwilioError < StandardError; end; end; end

  before do
    stub_const('Services::SmsService::TWILIO_CLIENT', twilio_client)
    Services::SmsService.instance_variable_set(:@client, nil)

    allow(Rails.application.credentials).to receive(:twilio).and_return(twilio_credentials)
    allow(Twilio::REST::Client).to receive(:new).and_return(twilio_client)
    allow(twilio_client).to receive(:messages).and_return(messages_proxy)
    allow(messages_proxy).to receive(:create).and_return(twilio_message)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '.dial' do
    context 'with valid parameters' do
      it 'calls the Twilio API to create a message' do
        ENV['TWILIO_PHONE_NUMBER'] = '+15005550001'
        expect(messages_proxy).to receive(:create).with(
          from: twilio_credentials[:phone_number],
          to: user.phone,
          body: 'Test message'
        )
        described_class.dial(to: user.phone, body: 'Test message')
      end

      it 'logs a success message' do
        expect(Rails.logger).to receive(:info).with(/SMS sent successfully/)
        described_class.dial(to: user.phone, body: 'Test message')
      end

      it 'returns true' do
        expect(described_class.dial(to: user.phone, body: 'Test message')).to be true
      end
    end

    context 'when the Twilio API raises an error' do
      before do
        allow(messages_proxy).to receive(:create).and_raise(Twilio::REST::TwilioError, 'An error occurred')
      end

      it 'logs an error message' do
        expect(Rails.logger).to receive(:error).with(/Twilio Error: Failed to send SMS/)
        described_class.dial(to: user.phone, body: 'Test message')
      end

      it 'returns false' do
        expect(described_class.dial(to: user.phone, body: 'Test message')).to be false
      end
    end

    context 'with invalid parameters' do
      it 'returns nil and does not call the API if `to` is blank' do
        expect(twilio_client).not_to receive(:messages)
        expect(described_class.dial(to: '', body: 'Test message')).to be_falsey
      end
    end
  end

  describe '.dial_2fa_code' do
    let(:code) { '123456' }

    context 'when the user has a phone number' do
      it 'calls the .dial method with a formatted message' do
        expected_body = "Your two-factor authentication code is: #{code}"
        expect(described_class).to receive(:dial).with(to: user.phone, body: expected_body)
        described_class.dial_2fa_code(user, code)
      end
    end

    context 'when the user does not have a phone number' do
      before { user.update!(phone: nil) }

      it 'does not call the .dial method' do
        expect(described_class).not_to receive(:dial)
        described_class.dial_2fa_code(user, code)
      end

      it 'returns false' do
        expect(described_class.dial_2fa_code(user, code)).to be false
      end
    end
  end
end
