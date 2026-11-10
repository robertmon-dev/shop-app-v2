# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::UserManagementService, type: :service do
  let!(:user) { create(:user, active: false, verified: false) }

  describe '.activate' do
    let(:valid_code) { 'valid_activation_code' }

    context 'with a valid activation code' do
      before do
        create(:activation_code, user: user, code: valid_code, expires_at: 1.hour.from_now)
      end

      it 'activates the user' do
        described_class.activate(user, valid_code)
        expect(user.reload.active).to be true
      end

      it 'destroys the used activation code' do
        expect do
          described_class.activate(user, valid_code)
        end.to change(ActivationCode, :count).by(-1)
      end

      it 'creates a new verification code' do
        expect do
          described_class.activate(user, valid_code)
        end.to change(VerificationCode, :count).by(1)
      end

      it 'returns a successful result' do
        result = described_class.activate(user, valid_code)
        expect(result.success?).to be true
        expect(result.status).to eq(:ok)
      end
    end

    context 'with an invalid activation code' do
      before do
        create(:activation_code, user: user, code: valid_code, expires_at: 1.hour.from_now)
      end

      it 'does not activate the user' do
        described_class.activate(user, 'invalid_code')
        expect(user.reload.active).to be false
      end

      it 'returns an unprocessable_content failure result' do
        result = described_class.activate(user, 'invalid_code')
        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
        expect(result.errors).to include('Invalid or expired activation code.')
      end
    end

    context 'with an expired activation code' do
      before do
        create(:activation_code, user: user, code: valid_code, expires_at: 1.hour.ago)
      end

      it 'does not activate the user' do
        described_class.activate(user, valid_code)
        expect(user.reload.active).to be false
      end
    end

    context 'when the user is not found' do
      it 'returns a not_found failure result' do
        result = described_class.activate(nil, valid_code)
        expect(result.success?).to be false
        expect(result.status).to eq(:not_found)
      end
    end
  end

  describe '.verify' do
    let(:valid_code) { 'valid_verification_code' }

    context 'with a valid verification code' do
      before do
        create(:verification_code, user: user, code: valid_code, expires_at: 1.hour.from_now)
      end

      it 'verifies the user' do
        described_class.verify(user, valid_code)
        expect(user.reload.verified).to be true
      end

      it 'destroys the used verification code' do
        expect do
          described_class.verify(user, valid_code)
        end.to change(VerificationCode, :count).by(-1)
      end

      it 'returns a successful result' do
        result = described_class.verify(user, valid_code)
        expect(result.success?).to be true
        expect(result.status).to eq(:ok)
      end
    end

    context 'with an invalid or expired code' do
      it 'does not verify the user' do
        described_class.verify(user, 'invalid_code')
        expect(user.reload.verified).to be false
      end

      it 'returns an unprocessable_content failure result' do
        result = described_class.verify(user, 'invalid_code')
        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
      end
    end
  end
end
