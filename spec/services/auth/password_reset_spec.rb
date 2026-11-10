# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::PasswordResetService, type: :service do
  include ActiveJob::TestHelper

  let!(:user) { create(:user, mail: 'test@example.com') }
  let(:mock_redis) { instance_double(Redis) }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(Redis).to receive(:current).and_return(mock_redis)
    allow(mock_redis).to receive(:get).and_return(nil)
    allow(mock_redis).to receive(:set).and_return('OK')
    allow(mock_redis).to receive(:del).and_return(1)
    ActionMailer::Base.deliveries.clear
  end

  describe '.request' do
    context 'when the user exists' do
      it 'saves the reset code to Redis' do
        expect(mock_redis).to receive(:set).with(a_string_matching(/^password_reset:/), user.id, ex: 7200)
        described_class.request('test@example.com')
      end

      it 'returns a successful result with a generic message' do
        result = described_class.request('test@example.com')
        expect(result.success?).to be true
        expect(result.message).to eq('If an account exists, instructions have been sent to your email.')
      end

      context 'when Redis is unavailable' do
        before do
          allow(mock_redis).to receive(:set).and_raise(Redis::CannotConnectError)
        end

        it 'creates a reset code in the database as a fallback' do
          expect do
            described_class.request('test@example.com')
          end.to change(ResetCode, :count).by(1)
          expect(user.reload.reset_code).not_to be_nil
        end
      end
    end

    context 'when the user does not exist' do
      it 'does not send an email' do
        expect do
          perform_enqueued_jobs do
            described_class.request('nonexistent@example.com')
          end
        end.not_to change(ActionMailer::Base.deliveries, :count)
      end

      it 'returns a successful result to prevent email enumeration' do
        result = described_class.request('nonexistent@example.com')
        expect(result.success?).to be true
        expect(result.message).to eq('If an account exists, instructions have been sent to your email.')
      end
    end
  end

  describe '.reset' do
    let(:password) { 'newStrongPassword123' }
    let(:reset_code) { 'valid_reset_code' }

    context 'with a valid code from Redis' do
      before do
        allow(mock_redis).to receive(:get).with("password_reset:#{reset_code}").and_return(user.id)
      end

      it 'resets the user password' do
        described_class.reset(reset_code, password, password)
        expect(user.reload.authenticate(password)).to be_truthy
      end

      it 'deletes the code from Redis after a successful reset' do
        expect(mock_redis).to receive(:del).with("password_reset:#{reset_code}")
        described_class.reset(reset_code, password, password)
      end

      it 'returns a successful result' do
        result = described_class.reset(reset_code, password, password)
        expect(result.success?).to be true
        expect(result.message).to eq('Password has been reset successfully.')
      end
    end

    context 'with a valid code from the database' do
      before do
        user.create_reset_code!(code: reset_code)
      end

      it 'resets the user password' do
        described_class.reset(reset_code, password, password)
        expect(user.reload.authenticate(password)).to be_truthy
      end

      it 'deletes the code from the database after a successful reset' do
        expect do
          described_class.reset(reset_code, password, password)
        end.to change(ResetCode, :count).by(-1)
      end
    end

    context 'with an invalid or expired code' do
      it 'returns a failure result' do
        result = described_class.reset('invalid_code', password, password)
        expect(result.success?).to be false
        expect(result.errors).to include('Invalid or expired reset code.')
      end

      it 'does not change the user password' do
        described_class.reset('invalid_code', password, password)
        expect(user.reload.authenticate(password)).to be false
      end
    end

    context 'when passwords do not match' do
      before do
        allow(mock_redis).to receive(:get).with("password_reset:#{reset_code}").and_return(user.id)
      end

      it 'returns a failure result' do
        result = described_class.reset(reset_code, password, 'different_password')
        expect(result.success?).to be false
        expect(result.errors).to include('Password and confirmation do not match.')
      end
    end
  end
end
