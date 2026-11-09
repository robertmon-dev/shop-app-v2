# frozen_string_literal: true

require 'swagger_helper'

describe 'Authentication API' do
  let!(:user) { create(:user, password: 'password', password_confirmation: 'password') }

  path '/api/v1/auth/login' do
    post 'Authenticates a user and returns a JWT' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          mail: { type: :string, example: 'user@example.com' },
          password: { type: :string, example: 'password' }
        },
        required: %w[mail password]
      }

      context 'with valid credentials' do
        response '200', 'login successful' do
          let(:credentials) { { mail: user.mail, password: 'password' } }

          schema type: :object, properties: {
            token: { type: :string, description: 'JWT for subsequent requests' },
            message: { type: :string }
          }

          after do |example|
            example.metadata[:response][:content] =
              { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
          end
          run_test!
        end
      end

      context 'when 2FA is required' do
        before do
          allow(Services::SmsService).to receive(:dial_2fa_code).and_return(true)
        end
        response '202', '2FA verification required' do
          let(:user_with_2fa) { create(:user, :two_factor_enabled, password: 'password') }
          let(:credentials) { { mail: user_with_2fa.mail, password: 'password' } }

          schema type: :object, properties: { message: { type: :string, example: '2FA code has been sent.' } }

          after do |example|
            example.metadata[:response][:content] =
              { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
          end
          run_test!
        end
      end

      context 'with invalid credentials' do
        response '401', 'invalid credentials' do
          let(:credentials) { { mail: user.mail, password: 'wrong_password' } }

          schema type: :object, properties: { errors: { type: :array, items: { type: :string } } }

          after do |example|
            example.metadata[:response][:content] =
              { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
          end
          run_test!
        end
      end
    end
  end

  path '/api/v1/auth/verify_2fa' do
    post 'Verifies a 2FA code' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :verification, in: :body, schema: {
        type: :object,
        properties: {
          mail: { type: :string, example: 'user@example.com' },
          second_factor_code: { type: :string, example: '123456' }
        },
        required: %w[mail second_factor_code]
      }

      let!(:user_with_2fa) { create(:user, :two_factor_enabled) }
      let!(:sfc) { create(:second_factor_code, user: user_with_2fa) }

      context 'with valid 2FA code' do
        response '200', '2FA successful, token returned' do
          let(:verification) { { mail: user_with_2fa.mail, second_factor_code: sfc.code } }

          schema type: :object, properties: { token: { type: :string } }

          after do |example|
            example.metadata[:response][:content] =
              { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
          end
          run_test!
        end
      end

      context 'with invalid 2FA code' do
        response '401', 'invalid 2FA code' do
          let(:verification) { { mail: user_with_2fa.mail, second_factor_code: 'wrong_code' } }

          schema type: :object, properties: { errors: { type: :array, items: { type: :string } } }

          after do |example|
            example.metadata[:response][:content] =
              { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
          end
          run_test!
        end
      end
    end
  end

  path '/api/v1/auth/activate' do
    patch 'Activates a user account' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :activation, in: :body, schema: {
        type: :object,
        properties: {
          mail: { type: :string, example: 'newuser@example.com' },
          activation_code: { type: :string, example: 'ABC-123' }
        },
        required: %w[mail activation_code]
      }

      let!(:inactive_user) { create(:user, :unactivated) }
      let!(:activation_code) { create(:activation_code, user: inactive_user) }

      context 'with a valid code' do
        response '200', 'account activated successfully' do
          let(:activation) { { mail: inactive_user.mail, activation_code: activation_code.code } }

          schema type: :object, properties: { message: { type: :string } }

          after do |example|
            example.metadata[:response][:content] =
              { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
          end
          run_test!
        end
      end

      context 'with an invalid code' do
        response '422', 'invalid activation code' do
          let(:activation) { { mail: inactive_user.mail, activation_code: 'wrong_code' } }

          schema type: :object, properties: { errors: { type: :array, items: { type: :string } } }

          after do |example|
            example.metadata[:response][:content] =
              { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
          end
          run_test!
        end
      end
    end
  end

  path '/api/v1/auth/password/reset' do
    post 'Requests a password reset' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :email_param, in: :body, schema: {
        type: :object,
        properties: {
          mail: { type: :string, example: 'user@example.com' }
        },
        required: ['mail']
      }, as: :email

      let(:email_param) { { mail: user.mail } }

      response '200', 'password reset instructions sent' do
        schema type: :object, properties: { message: { type: :string } }

        after do |example|
          example.metadata[:response][:content] =
            { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
        end
        run_test!
      end
    end

    patch 'Confirms a password reset' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :reset_details, in: :body, schema: {
        type: :object,
        properties: {
          reset_code: { type: :string, example: 'XYZ-789' },
          password: { type: :string, example: 'newPassword123' },
          password_confirmation: { type: :string, example: 'newPassword123' }
        },
        required: %w[reset_code password password_confirmation]
      }

      let!(:user_for_reset) { create(:user) }
      let!(:reset_code) { create(:reset_code, user: user_for_reset) }

      context 'with a valid reset code' do
        response '200', 'password has been reset successfully' do
          let(:reset_details) do
            { reset_code: reset_code.code, password: 'newPassword123', password_confirmation: 'newPassword123' }
          end

          schema type: :object, properties: { message: { type: :string } }

          after do |example|
            example.metadata[:response][:content] =
              { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
          end
          run_test!
        end
      end

      context 'with an invalid reset code' do
        response '422', 'invalid code or password mismatch' do
          let(:reset_details) do
            { reset_code: 'wrong_code', password: 'newPassword123', password_confirmation: 'newPassword123' }
          end

          schema type: :object, properties: { errors: { type: :array, items: { type: :string } } }

          after do |example|
            example.metadata[:response][:content] =
              { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
          end
          run_test!
        end
      end
    end
  end
end
