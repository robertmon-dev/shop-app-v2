# frozen_string_literal: true

require 'swagger_helper'

describe 'Users API' do
  let!(:regular_user) { create(:user, :with_detail) }
  let(:regular_user_token) { Auth::Bearer.encode({ user_id: regular_user.id }).data[:token] }
  let!(:admin_user) { create(:user, :admin, :with_detail) }
  let(:admin_user_token) { Auth::Bearer.encode({ user_id: admin_user.id }).data[:token] }
  let!(:other_user) { create(:user) }

  let(:user_response_schema) do
    {
      type: :object,
      properties: {
        user: { '$ref' => '#/components/schemas/User' }
      },
      required: ['user']
    }
  end

  path '/api/v1/users' do
    get 'Lists all users (Admin only)' do
      tags 'Users'
      produces 'application/json'
      security [Bearer: []]

      context 'as an admin' do
        let(:Authorization) { "Bearer #{admin_user_token}" }
        response '200', 'returns a list of users' do
          schema type: :object, properties: {
            users: { type: :array, items: { '$ref' => '#/components/schemas/User' } }
          }
          run_test!
        end
      end

      context 'as a regular user' do
        let(:Authorization) { "Bearer #{regular_user_token}" }
        response '403', 'forbidden' do
          run_test!
        end
      end
    end

    post 'Creates a new user (registration)' do
      tags 'Users'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :user_params, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              mail: { type: :string, example: 'test@example.com' },
              password: { type: :string, example: 'password123' },
              password_confirmation: { type: :string, example: 'password123' },
              phone: { type: :string, example: '123456789' },
              user_detail_attributes: {
                type: :object,
                properties: {
                  name: { type: :string, example: 'John Doe' }
                }
              }
            },
            required: %w[mail password password_confirmation]
          }
        }
      }

      let(:user_params) { { user: attributes_for(:user).merge(user_detail_attributes: attributes_for(:user_detail)) } }

      response '201', 'user created' do
        schema all_of: [{ '$ref' => '#/components/schemas/User' }],
               properties: { user: { '$ref' => '#/components/schemas/User' } }
        run_test!
      end

      response '422', 'invalid parameters' do
        let(:user_params) { { user: { mail: 'invalid' } } }
        run_test!
      end
    end
  end

  path '/api/v1/users/me' do
    get 'Retrieves the current user profile' do
      tags 'Users'
      produces 'application/json'
      security [Bearer: []]
      let(:Authorization) { "Bearer #{regular_user_token}" }

      response '200', 'returns current user profile' do
        schema all_of: [{ '$ref' => '#/components/schemas/User' }],
               properties: { user: { '$ref' => '#/components/schemas/User' } }
        run_test!
      end
    end
  end

  path '/api/v1/users/logout' do
    post 'Logs out the current user' do
      tags 'Users'
      produces 'application/json'
      security [Bearer: []]
      let(:Authorization) { "Bearer #{regular_user_token}" }

      response '200', 'logout successful' do
        schema type: :object, properties: { message: { type: :string } }
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true
    let(:id) { regular_user.id }

    get 'Retrieves a user profile' do
      tags 'Users'
      produces 'application/json'
      security [Bearer: []]

      context 'as self' do
        let(:Authorization) { "Bearer #{regular_user_token}" }
        response '200', 'returns own profile' do
          schema all_of: [{ '$ref' => '#/components/schemas/User' }],
                 properties: { user: { '$ref' => '#/components/schemas/User' } }
          run_test!
        end
      end

      context 'as an admin viewing another user' do
        let(:Authorization) { "Bearer #{admin_user_token}" }
        let(:id) { other_user.id }
        response '200', 'returns other user profile' do
          run_test!
        end
      end

      context 'as a regular user viewing another user' do
        let(:Authorization) { "Bearer #{regular_user_token}" }
        let(:id) { other_user.id }
        response '403', 'forbidden' do
          run_test!
        end
      end
    end

    put 'Updates a user profile' do
      tags 'Users'
      consumes 'application/json'
      security [Bearer: []]
      parameter name: :user_params, in: :body, schema: {
        # Taki sam schemat jak dla `create`, ale pola nie są wymagane
      }
      let(:user_params) { { user: { phone: '987654321' } } }

      context 'as self' do
        let(:Authorization) { "Bearer #{regular_user_token}" }
        response '200', 'profile updated' do
          run_test!
        end
      end
    end

    delete 'Deletes a user account' do
      tags 'Users'
      security [Bearer: []]

      context 'as self' do
        let(:Authorization) { "Bearer #{regular_user_token}" }
        response '204', 'account deleted' do
          run_test!
        end
      end

      context 'as an admin' do
        let(:id) { other_user.id }
        let(:Authorization) { "Bearer #{admin_user_token}" }
        response '204', 'other account deleted' do
          run_test!
        end
      end
    end
  end

  path '/api/v1/users/{id}/role/update' do
    patch 'Updates a user role (Admin only)' do
      tags 'Users'
      consumes 'application/json'
      security [Bearer: []]
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :role_params, in: :body, schema: {
        type: :object, properties: { role: { type: :string, example: 'moderator' } }
      }

      let(:id) { regular_user.id }
      let(:role_params) { { role: 'moderator' } }

      context 'as an admin' do
        let(:Authorization) { "Bearer #{admin_user_token}" }
        response '200', 'role updated' do
          run_test!
        end
      end

      context 'as a regular user' do
        let(:Authorization) { "Bearer #{regular_user_token}" }
        response '403', 'forbidden' do
          run_test!
        end
      end
    end
  end

  path '/api/v1/users/{id}/update_details' do
    patch 'Updates user details' do
      tags 'Users'
      consumes 'application/json'
      security [Bearer: []]
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :detail_params, in: :body, schema: {
        type: :object, properties: {
          user_detail: {
            type: :object, properties: {
              first_name: { type: :string, example: 'Jane' },
              last_name: { type: :string, example: 'Doe' }
            }
          }
        }
      }

      let(:id) { regular_user.id }
      let(:detail_params) { { user_detail: { first_name: 'Jane' } } }

      context 'as self' do
        let(:Authorization) { "Bearer #{regular_user_token}" }
        response '200', 'details updated' do
          run_test!
        end
      end
    end
  end
end
