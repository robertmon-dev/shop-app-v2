# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::BearerService, type: :service do
  let(:payload) { { user_id: 1, name: 'Test User' } }
  let(:secret_key) { 'test_secret_key' }
  let(:token) { JWT.encode(payload.merge(exp: Time.now.to_i + 3600), secret_key, 'HS256') }
  let(:redis_double) { double('Redis') }

  before do
    stub_const('Services::BearerService::SECRET_KEY', secret_key)
    allow(described_class).to receive(:redis).and_return(redis_double)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
  end

  describe '.encode' do
    context 'when successful' do
      it 'encodes a payload into a JWT and caches it in Redis' do
        allow(redis_double).to receive(:set)
        result = described_class.encode(payload)

        expect(redis_double).to have_received(:set).with(a_string_starting_with('jwt_status:'), 'active',
                                                         ex: described_class::TOKEN_LIFETIME)
        expect(result.success?).to be true
        expect(result.data[:token]).to be_a(String)
      end

      it 'returns a token even if Redis connection fails' do
        allow(redis_double).to receive(:set).and_raise(Redis::CannotConnectError)
        result = described_class.encode(payload)

        expect(Rails.logger).to have_received(:error).with(/Redis error: Failed to cache JWT/)
        expect(result.success?).to be true
        expect(result.data[:token]).to be_a(String)
      end
    end
  end

  describe '.decode' do
    context 'when token is valid and not blacklisted' do
      it 'decodes the token successfully' do
        allow(described_class).to receive(:blacklisted?).with(token).and_return(Services::Result.new(success?: true,
                                                                                                     data: { is_blacklisted: false }))
        result = described_class.decode(token)

        expect(result.success?).to be true
        expect(result.data[:payload][:user_id]).to eq(payload[:user_id])
      end
    end

    context 'when token is blacklisted' do
      it 'returns an unauthorized error' do
        allow(described_class).to receive(:blacklisted?).with(token).and_return(Services::Result.new(success?: true,
                                                                                                     data: { is_blacklisted: true }))
        result = described_class.decode(token)

        expect(result.success?).to be false
        expect(result.status).to eq(:unauthorized)
        expect(result.errors.first).to eq('Token has been blacklisted')
      end
    end

    context 'when token is expired' do
      let(:expired_payload) { payload.merge(exp: Time.now.to_i - 3600) }
      let(:expired_token) { JWT.encode(expired_payload, secret_key, 'HS256') }

      it 'returns an unauthorized error' do
        allow(described_class).to receive(:blacklisted?).with(expired_token).and_return(Services::Result.new(
                                                                                          success?: true, data: { is_blacklisted: false }
                                                                                        ))
        result = described_class.decode(expired_token)

        expect(result.success?).to be false
        expect(result.status).to eq(:unauthorized)
        expect(result.errors).to include('Token has expired.')
      end
    end
  end

  describe '.blacklist!' do
    context 'with a valid token' do
      it 'blacklists the token in Redis' do
        allow(redis_double).to receive(:set)
        result = described_class.blacklist!(token)

        expect(redis_double).to have_received(:set).with("jwt_status:#{token}", 'blacklisted',
                                                         ex: described_class::TOKEN_LIFETIME)
        expect(result.success?).to be true
      end

      it 'blacklists the token in the database when Redis fails' do
        allow(redis_double).to receive(:set).and_raise(Redis::CannotConnectError)
        allow(BlacklistedToken).to receive(:create!)

        result = described_class.blacklist!(token)

        expect(BlacklistedToken).to have_received(:create!).with(token: token, owner_id: payload[:user_id],
                                                                 expires_at: anything)
        expect(result.success?).to be true
      end

      it 'returns an error if both Redis and DB fail' do
        allow(redis_double).to receive(:set).and_raise(Redis::CannotConnectError)
        allow(BlacklistedToken).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new)

        result = described_class.blacklist!(token)
        expect(Rails.logger).to have_received(:error).with('Validation failed: Record invalid')
        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
      end
    end

    context 'with an invalid token' do
      it 'returns an unprocessable_content error' do
        result = described_class.blacklist!('invalid.token.string')
        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
      end
    end
  end

  describe '.blacklisted?' do
    let(:redis_key) { "jwt_status:#{token}" }

    it 'returns true if token is blacklisted in Redis' do
      allow(redis_double).to receive(:get).with(redis_key).and_return('blacklisted')
      result = described_class.blacklisted?(token)
      expect(result.data[:is_blacklisted]).to be true
    end

    it 'returns false if token is not blacklisted in Redis' do
      allow(redis_double).to receive(:get).with(redis_key).and_return('active')
      result = described_class.blacklisted?(token)
      expect(result.data[:is_blacklisted]).to be false
    end

    it 'checks the database if Redis fails and token exists in DB' do
      allow(redis_double).to receive(:get).and_raise(Redis::CannotConnectError)
      allow(BlacklistedToken).to receive(:exists?).with(token: token).and_return(true)

      result = described_class.blacklisted?(token)
      expect(result.data[:is_blacklisted]).to be true
    end
  end
end
