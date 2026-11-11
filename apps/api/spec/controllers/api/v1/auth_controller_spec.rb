# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::AuthController, type: :controller do
  render_views

  let(:auth_service) { class_double(Auth::Authentication) }
  let(:user_management_service) { class_double(Users::Management) }
  let(:password_service) { class_double(Auth::PasswordReset) }
  let(:user) { create(:user, :with_detail, mail: 'test@example.com', password: 'password') }

  before do
    stub_const('Auth::Authentication', auth_service)
    stub_const('Users::Management', user_management_service)
    stub_const('Auth::PasswordReset', password_service)
  end

  describe 'POST #login' do
    context 'with valid credentials and no 2FA' do
      it 'returns a successful response with user data and token' do
        result = instance_double(ApplicationService::Result,
                                 success?: true, data: { token: 'some_token', user: user }, status: :ok,
                                 message: 'Logged in successfully.', errors: [])
        allow(auth_service).to receive(:login).with('test@example.com', 'password').and_return(result)

        post :login, params: { mail: 'test@example.com', password: 'password' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['token']).to eq('some_token')
      end
    end

    context 'with valid credentials and 2FA enabled' do
      it 'returns an accepted status with a message to verify 2FA' do
        result = instance_double(ApplicationService::Result,
                                 success?: true, status: :accepted, data: { user_id: user.id },
                                 message: 'Two-factor authentication code sent. Please verify.', errors: [])
        allow(auth_service).to receive(:login).with('test@example.com', 'password').and_return(result)

        post :login, params: { mail: 'test@example.com', password: 'password' }

        expect(response).to have_http_status(:accepted)
      end
    end

    context 'with invalid credentials' do
      it 'returns an unauthorized status' do
        result = instance_double(ApplicationService::Result,
                                 success?: false, status: :unauthorized, errors: ['Invalid email or password.'],
                                 message: 'Authentication failed.', data: {})
        allow(auth_service).to receive(:login).with('test@example.com', 'wrong_password').and_return(result)

        post :login, params: { mail: 'test@example.com', password: 'wrong_password' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with missing parameters' do
      it 'returns an unauthorized status' do
        result = instance_double(ApplicationService::Result,
                                 success?: false, status: :unauthorized, errors: ['Invalid email or password.'],
                                 message: 'Authentication failed.', data: {})
        allow(auth_service).to receive(:login).with('test@example.com', nil).and_return(result)

        post :login, params: { mail: 'test@example.com' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #verify_2fa' do
    before do
      allow(User).to receive(:find_by).with(mail: 'test@example.com').and_return(user)
      allow(User).to receive(:find_by).with(mail: 'unknown@example.com').and_return(nil)
    end

    context 'with valid 2FA code' do
      it 'returns a successful response with token' do
        result = instance_double(ApplicationService::Result,
                                 success?: true, data: { token: '2fa_token' }, status: :ok,
                                 message: '2FA verified successfully.', errors: [])
        allow(auth_service).to receive(:verify_2fa).with(user, 'valid_code').and_return(result)

        post :verify_2fa, params: { mail: 'test@example.com', second_factor_code: 'valid_code' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid 2FA code' do
      it 'returns an unauthorized status' do
        result = instance_double(ApplicationService::Result,
                                 success?: false, status: :unauthorized, errors: ['Invalid 2FA code.'],
                                 message: 'Invalid two-factor authentication code.', data: {})
        allow(auth_service).to receive(:verify_2fa).with(user, 'invalid_code').and_return(result)

        post :verify_2fa, params: { mail: 'test@example.com', second_factor_code: 'invalid_code' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user is not found' do
      it 'returns an not found status' do
        allow(controller).to receive(:set_user_by_mail).and_call_original
        post :verify_2fa, params: { mail: 'unknown@example.com', second_factor_code: 'some_code' }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH #activate' do
    before do
      allow(User).to receive(:find_by).with(mail: 'test@example.com').and_return(user)
      allow(User).to receive(:find_by).with(mail: 'unknown@example.com').and_return(nil)
    end

    context 'with valid activation code' do
      it 'returns a successful response' do
        result = instance_double(ApplicationService::Result,
                                 success?: true, data: { user: user }, status: :ok,
                                 message: 'Account activated successfully.', errors: [])
        allow(user_management_service).to receive(:activate).with(user, 'valid_code').and_return(result)

        patch :activate, params: { mail: 'test@example.com', activation_code: 'valid_code' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid activation code' do
      it 'returns an unprocessable entity status' do
        result = instance_double(ApplicationService::Result,
                                 success?: false, status: :unprocessable_content, errors: ['Invalid code.'],
                                 message: 'Activation failed.', data: {})
        allow(user_management_service).to receive(:activate).with(user, 'invalid_code').and_return(result)

        patch :activate, params: { mail: 'test@example.com', activation_code: 'invalid_code' }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when user is not found' do
      it 'returns an not found status' do
        patch :activate, params: { mail: 'unknown@example.com', activation_code: 'some_code' }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH #verify' do
    before do
      allow(User).to receive(:find_by).with(mail: 'test@example.com').and_return(user)
      allow(User).to receive(:find_by).with(mail: 'unknown@example.com').and_return(nil)
    end

    context 'with valid verification code' do
      it 'returns a successful response' do
        result = instance_double(ApplicationService::Result,
                                 success?: true, data: { user: user }, status: :ok,
                                 message: 'Account verified successfully.', errors: [])
        allow(user_management_service).to receive(:verify).with(user, 'valid_code').and_return(result)

        patch :verify, params: { mail: 'test@example.com', verification_code: 'valid_code' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid verification code' do
      it 'returns an unprocessable entity status' do
        result = instance_double(ApplicationService::Result,
                                 success?: false, status: :unprocessable_content, errors: ['Invalid code.'],
                                 message: 'Verification failed.', data: {})
        allow(user_management_service).to receive(:verify).with(user, 'invalid_code').and_return(result)

        patch :verify, params: { mail: 'test@example.com', verification_code: 'invalid_code' }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when user is not found' do
      it 'returns an not found status' do
        patch :verify, params: { mail: 'unknown@example.com', verification_code: 'some_code' }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #request_reset' do
    context 'with valid email' do
      it 'returns a successful response' do
        result = instance_double(ApplicationService::Result,
                                 success?: true, status: :ok, message: 'Password reset requested.',
                                 errors: [], data: {})
        allow(password_service).to receive(:request).with('test@example.com').and_return(result)

        post :request_reset, params: { mail: 'test@example.com' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when user is not found' do
      it 'returns a successful response to prevent enumeration' do
        result = instance_double(ApplicationService::Result,
                                 success?: true, status: :ok, message: 'If the email exists...',
                                 errors: [], data: {})
        allow(password_service).to receive(:request).with('unknown@example.com').and_return(result)

        post :request_reset, params: { mail: 'unknown@example.com' }

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'PATCH #confirm_reset' do
    context 'with valid reset code and matching passwords' do
      it 'returns a successful response' do
        result = instance_double(ApplicationService::Result,
                                 success?: true, status: :ok, message: 'Password reset successfully',
                                 errors: [], data: {})
        allow(password_service).to receive(:reset).with('valid_code', 'new_password', 'new_password').and_return(result)

        patch :confirm_reset,
              params: { reset_code: 'valid_code', password: 'new_password', password_confirmation: 'new_password' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid reset code' do
      it 'returns an unprocessable entity status' do
        result = instance_double(ApplicationService::Result,
                                 success?: false, status: :unprocessable_content, errors: ['Invalid code'],
                                 message: 'Reset failed.', data: {})
        allow(password_service).to receive(:reset).with('invalid_code', 'new_password',
                                                        'new_password').and_return(result)

        patch :confirm_reset,
              params: { reset_code: 'invalid_code', password: 'new_password', password_confirmation: 'new_password' }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with mismatched passwords' do
      it 'returns an unprocessable entity status' do
        result = instance_double(ApplicationService::Result,
                                 success?: false, status: :unprocessable_content, errors: ['Passwords do not match'],
                                 message: 'Passwords do not match.', data: {})
        allow(password_service).to receive(:reset).with('valid_code', 'new_password',
                                                        'different_password').and_return(result)

        patch :confirm_reset,
              params: { reset_code: 'valid_code', password: 'new_password',
                        password_confirmation: 'different_password' }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
