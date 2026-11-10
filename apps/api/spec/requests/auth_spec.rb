# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Auth', type: :request do
  let(:json) { JSON.parse(response.body) }

  describe 'POST /api/v1/auth/login' do
    let!(:user) do
      create(:user, :with_detail, password: 'password123', password_confirmation: 'password123', active: true,
                                  verified: true)
    end
    let(:login_params) { { mail: user.mail, password: 'password123' } }

    context 'with valid credentials' do
      it 'returns a successful response' do
        post '/api/v1/auth/login', params: login_params
        expect(response).to have_http_status(:ok)
        expect(json['data']['token']).not_to be_empty
      end
    end

    context 'with invalid credentials' do
      it 'returns an unauthorized error' do
        post '/api/v1/auth/login', params: { mail: user.mail, password: 'wrongpassword' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/auth/verify_2fa' do
    let!(:user) { create(:user, :with_detail, :two_factor_enabled) }
    let!(:second_factor_code) { create(:second_factor_code, user: user) }

    context 'with a valid 2FA code' do
      it 'returns a new token and a success message' do
        post '/api/v1/auth/verify_2fa', params: { mail: user.mail, second_factor_code: second_factor_code.code }
        expect(response).to have_http_status(:ok)
        expect(json['message']).to eq('2FA verified successfully via database.')
      end
    end

    context 'with an invalid 2FA code' do
      it 'returns an unauthorized error' do
        post '/api/v1/auth/verify_2fa', params: { mail: user.mail, second_factor_code: '000000' }
        expect(response).to have_http_status(:unauthorized)
        expect(json['errors']).to include('Invalid 2FA code.')
      end

      it 'does not issue a token when the code is missing' do
        post '/api/v1/auth/verify_2fa', params: { mail: user.mail }
        expect(response).to have_http_status(:unauthorized)
        expect(response.body).not_to include('token')
      end
    end
  end

  describe 'PATCH /api/v1/auth/activate' do
    context 'with a valid activation code' do
      let!(:user) { create(:user, :with_detail, :unactivated) }
      let!(:activation_code) { create(:activation_code, user: user) }

      it 'activates the user and returns a success message' do
        patch '/api/v1/auth/activate', params: { mail: user.mail, activation_code: activation_code.code }
        expect(response).to have_http_status(:ok)
        expect(json['message']).to eq('Account activated successfully.')
        expect(user.reload.active?).to be true
      end
    end

    context 'with an invalid activation code' do
      let!(:user) { create(:user, :with_detail, :unactivated) }
      let!(:activation_code) { create(:activation_code, user: user) }

      it 'does not activate the user and returns an error' do
        patch '/api/v1/auth/activate', params: { mail: user.mail, activation_code: 'invalid_code' }
        expect(response).to have_http_status(:unprocessable_content)
        expect(json['errors']).to include('Invalid or expired activation code.')
        expect(user.reload.active?).to be false
      end
    end
  end

  describe 'PATCH /api/v1/auth/verify' do
    let!(:user) { create(:user, :with_detail, :unverified) }
    let!(:verification_code) { create(:verification_code, user: user) }

    context 'with a valid verification code' do
      it 'verifies the user and returns a success message' do
        patch '/api/v1/auth/verify', params: { mail: user.mail, verification_code: verification_code.code }
        expect(response).to have_http_status(:ok)
        expect(json['message']).to eq('Account verified successfully.')
        expect(user.reload.verified?).to be true
      end
    end

    context 'with an invalid verification code' do
      it 'does not verify the user and returns an error' do
        patch '/api/v1/auth/verify', params: { mail: user.mail, verification_code: 'invalid_code' }
        expect(response).to have_http_status(:unprocessable_content)
        expect(json['errors']).to include('Invalid or expired verification code.')
        expect(user.reload.verified?).to be false
      end
    end
  end

  describe 'POST /api/v1/auth/password/reset' do
    let!(:user) { create(:user, :with_detail) }

    include ActiveJob::TestHelper

    context 'when the user exists' do
      it 'sends reset instructions, returns a success message, and enqueues a mailer job' do
        clear_enqueued_jobs

        expect do
          post '/api/v1/auth/password/reset', params: { mail: user.mail }
        end.to have_enqueued_job(ActionMailer::MailDeliveryJob).once

        expect(response).to have_http_status(:ok)
        expect(json['message']).to eq('If an account exists, instructions have been sent to your email.')
      end
    end
  end

  describe 'PATCH /api/v1/auth/password/reset' do
    let!(:user) { create(:user, :with_detail) }
    let!(:reset_code) { create(:reset_code, user: user) }

    context 'with a valid reset code and matching passwords' do
      it 'resets the password and returns a success message' do
        patch '/api/v1/auth/password/reset', params: {
          reset_code: reset_code.code,
          password: 'newPassword123',
          password_confirmation: 'newPassword123'
        }
        expect(response).to have_http_status(:ok)
        expect(json['message']).to eq('Password has been reset successfully.')
        expect(user.reload.authenticate('newPassword123')).to be_truthy
      end
    end

    context 'with an invalid reset code' do
      it 'returns an unprocessable entity error' do
        patch '/api/v1/auth/password/reset',
              params: { reset_code: 'invalid_token', password: 'pw', password_confirmation: 'pw' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json['errors']).to include('Invalid or expired reset code.')
      end
    end
  end
end
