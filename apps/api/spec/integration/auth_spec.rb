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

          schema envelope_schema(token: { type: :string, description: 'JWT for subsequent requests' })

          after do |example|
            example.metadata[:response][:content] =
              { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
          end
          run_test!
        end
      end

      context 'when 2FA is required' do
        before do
          allow(Notifications::Sms).to receive(:dial_2fa_code).and_return(true)
        end
        response '202', '2FA verification required' do
          let(:user_with_2fa) { create(:user, :two_factor_enabled, password: 'password') }
          let(:credentials) { { mail: user_with_2fa.mail, password: 'password' } }

          schema envelope_schema(user_id: { type: :integer }, two_factor_required: { type: :boolean })

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

          schema failure_schema

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

          schema envelope_schema(token: { type: :string }, user: ref(:User))

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

          schema failure_schema

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

          schema envelope_schema(user: ref(:User))

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

          schema failure_schema

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
        schema message_schema

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

          schema message_schema

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

          schema failure_schema

          after do |example|
            example.metadata[:response][:content] =
              { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
          end
          run_test!
        end
      end
    end
  end
  path '/api/v1/auth/verify' do
    patch 'Verifies a user account' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object, properties: { mail: { type: :string }, verification_code: { type: :string } },
        required: %w[mail verification_code]
      }
      let(:unverified) { create(:user, :unverified) }
      let!(:verification_code) { create(:verification_code, user: unverified) }
      let(:body) { { mail: unverified.mail, verification_code: verification_code.code } }

      response '200', 'account verified' do
        schema envelope_schema(user: ref(:User))
        run_test!
      end

      response '422', 'invalid verification code' do
        let(:body) { { mail: unverified.mail, verification_code: 'wrong' } }
        schema failure_schema
        run_test!
      end
    end
  end

  {
    'request_activation_code_resend' => :unactivated,
    'request_verification_code_resend' => :unverified,
    'request_2fa_code_resend' => :two_factor_enabled
  }.each do |action, trait|
    path "/api/v1/auth/#{action}" do
      post "Resends the code (#{action})" do
        tags 'Authentication'
        consumes 'application/json'
        produces 'application/json'
        parameter name: :body, in: :body, schema: {
          type: :object, properties: { mail: { type: :string } }, required: ['mail']
        }
        let(:target) { create(:user, trait) }
        let!(:activation_code) { create(:activation_code, user: target) if trait == :unactivated }
        let!(:verification_code) { create(:verification_code, user: target) if trait == :unverified }
        let(:body) { { mail: target.mail } }

        response '200', 'code resent' do
          schema message_schema
          run_test!
        end

        response '404', 'user not found' do
          let(:body) { { mail: 'nobody@example.com' } }
          schema failure_schema
          run_test!
        end
      end
    end
  end

  path '/api/v1/auth/request_reset_code_resend' do
    post 'Requests a new password reset code' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object, properties: { mail: { type: :string } }, required: ['mail']
      }
      let(:body) { { mail: user.mail } }

      response '200', 'instructions sent if the account exists' do
        schema message_schema
        run_test!
      end
    end
  end
end
