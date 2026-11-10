# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::AuthenticationService, type: :service do
  let(:password) { 'password' }
  let(:token) { 'sample.jwt.token' }

  let(:success_token_result) { Services::Result.new(success?: true, data: { token: token }) }
  let(:failed_token_result) { Services::Result.new(success?: false, errors: ['Token generation failed']) }
  let(:bearer_service_double) { double('BearerService') }
  let(:sms_service_double) { double('SMSService') }
  let(:user_mailer_double) { double('UserMailer') }
  let(:mailer_delivery_double) { double('ActionMailer::MessageDelivery') }
  let(:redis_double) { double('Redis') }

  before do
    stub_const('Services::BearerService', bearer_service_double)
    stub_const('Services::SmsService', sms_service_double)

    stub_const('UserMailer', user_mailer_double)

    allow(bearer_service_double).to receive(:encode).and_return(success_token_result)
    allow(bearer_service_double).to receive(:blacklist!)
    allow(bearer_service_double).to receive(:redis).and_return(redis_double)
    allow(redis_double).to receive(:get).and_return(nil)
    allow(redis_double).to receive(:set)
    allow(redis_double).to receive(:del)

    allow(sms_service_double).to receive(:dial_2fa_code)

    allow(user_mailer_double).to receive(:dial_2fa_code).and_return(mailer_delivery_double)
    allow(mailer_delivery_double).to receive(:deliver_later)

    allow(Rails.logger).to receive(:error)
    allow(SecureRandom).to receive(:hex).and_return('random_hex_code')
  end

  describe '.login' do
    let(:user) { create(:user, password: password, password_confirmation: password) }

    context 'when credentials are valid' do
      context 'and user does not have 2FA enabled' do
        it 'returns a successful result with a JWT token' do
          result = described_class.login(user.mail, password)

          expect(bearer_service_double).to have_received(:encode).with({ user_id: user.id })
          expect(result.success?).to be true
          expect(result.data[:token]).to eq(token)
        end

        it 'returns a failure result if token generation fails' do
          allow(bearer_service_double).to receive(:encode).and_return(failed_token_result)
          result = described_class.login(user.mail, password)

          expect(result.success?).to be false
          expect(result.errors).to include('Token generation failed')
        end
      end

      context 'and user has 2FA enabled' do
        let(:user_with_2fa) { create(:user, :two_factor_enabled, password: password, password_confirmation: password) }

        it 'sends a 2FA code and returns an :accepted result' do
          allow(described_class).to receive(:send_2fa_code).and_call_original
          result = described_class.login(user_with_2fa.mail, password)

          expect(sms_service_double).to have_received(:dial_2fa_code).with(user_with_2fa, anything)
          expect(result.success?).to be true
        end
      end
    end

    context 'when credentials are invalid' do
      it 'returns an error if the password is invalid' do
        result = described_class.login(user.mail, 'wrong_password')
        expect(result.success?).to be false
      end
    end
  end

  describe '.verify_2fa' do
    let(:user) { create(:user) }
    let(:code) { '123456' }

    it 'uses Redis for verification and returns a token' do
      allow(redis_double).to receive(:get).with("user:#{user.id}:2fa_code").and_return(code)
      result = described_class.verify_2fa(user, code)

      expect(redis_double).to have_received(:del).with("user:#{user.id}:2fa_code")
      expect(bearer_service_double).to have_received(:encode).with({ user_id: user.id })
      expect(result.success?).to be true
    end

    it 'uses the database as a fallback when Redis is unavailable' do
      db_code = create(:second_factor_code, user: user)
      allow(redis_double).to receive(:get).and_raise(Redis::CannotConnectError.new)
      result = described_class.verify_2fa(user, db_code.code)

      expect(bearer_service_double).to have_received(:encode).with({ user_id: user.id })
      expect(SecondFactorCode.find_by(id: db_code.id)).to be_nil
      expect(result.success?).to be true
    end
  end

  describe '.blacklist_token' do
    it 'calls BearerService.blacklist!' do
      described_class.blacklist_token(token)
      expect(bearer_service_double).to have_received(:blacklist!).with(token)
    end
  end

  describe '.send_2fa_code' do
    let(:user) { create(:user) }
    before { allow(described_class).to receive(:send_2fa_code).and_call_original }

    it 'saves the 2FA code in Redis' do
      described_class.send(:send_2fa_code, user)
      expect(redis_double).to have_received(:set).with(a_string_starting_with("user:#{user.id}"), anything, ex: 900)
    end

    it 'saves the 2FA code to the database as a fallback when Redis is not available' do
      allow(redis_double).to receive(:set).and_raise(Redis::CannotConnectError)
      expect { described_class.send(:send_2fa_code, user) }.to change(SecondFactorCode, :count).by(1)
    end
  end
end
