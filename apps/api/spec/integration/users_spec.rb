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
      security [{ Bearer: [] }]

      context 'as an admin' do
        let(:Authorization) { "Bearer #{admin_user_token}" }
        response '200', 'returns a list of users' do
          schema envelope_schema({ users: list(:User) }, meta: true)
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
        schema envelope_schema(user: ref(:UserProfile))
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
      security [{ Bearer: [] }]
      let(:Authorization) { "Bearer #{regular_user_token}" }

      response '200', 'returns current user profile' do
        schema envelope_schema(user: ref(:UserProfile))
        run_test!
      end
    end
  end

  path '/api/v1/users/logout' do
    post 'Logs out the current user' do
      tags 'Users'
      produces 'application/json'
      security [{ Bearer: [] }]
      let(:Authorization) { "Bearer #{regular_user_token}" }

      response '200', 'logout successful' do
        schema message_schema
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
      security [{ Bearer: [] }]

      context 'as self' do
        let(:Authorization) { "Bearer #{regular_user_token}" }
        response '200', 'returns own profile' do
          schema envelope_schema(user: ref(:UserProfile))
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
      produces 'application/json'
      security [{ Bearer: [] }]
      parameter name: :user_params, in: :body, schema: {
        # Taki sam schemat jak dla `create`, ale pola nie są wymagane
      }
      let(:user_params) { { user: { phone: '987654321' } } }

      context 'as self' do
        let(:Authorization) { "Bearer #{regular_user_token}" }
        response '200', 'profile updated' do
          schema envelope_schema(user: ref(:UserProfile))
          run_test!
        end
      end
    end

    delete 'Deletes a user account' do
      tags 'Users'
      security [{ Bearer: [] }]

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
      produces 'application/json'
      security [{ Bearer: [] }]
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :role_params, in: :body, schema: {
        type: :object, properties: { role: { type: :string, example: 'moderator' } }
      }

      let(:id) { regular_user.id }
      let(:role_params) { { role: 'moderator' } }

      context 'as an admin' do
        let(:Authorization) { "Bearer #{admin_user_token}" }
        response '200', 'role updated' do
          schema envelope_schema(user: ref(:UserProfile))
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
      produces 'application/json'
      security [{ Bearer: [] }]
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
          schema envelope_schema(user: ref(:UserProfile))
          run_test!
        end
      end
    end
  end
  path '/api/v1/users/{id}' do
    parameter name: :id, in: :path, type: :integer
    let(:id) { regular_user.id }

    patch 'Updates a user profile' do
      tags 'Users'
      consumes 'application/json'
      produces 'application/json'
      security [{ Bearer: [] }]
      parameter name: :body, in: :body, schema: {
        type: :object, properties: { user: { type: :object,
                                             properties: { phone: { type: :string } } } }, required: ['user']
      }
      let(:Authorization) { "Bearer #{regular_user_token}" }
      let(:body) { { user: { phone: '555123456' } } }

      response '200', 'profile updated' do
        schema envelope_schema(user: ref(:UserProfile))
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}/actions' do
    parameter name: :id, in: :path, type: :integer
    let(:id) { regular_user.id }

    get 'Lists the actions performed by a user' do
      tags 'Users'
      produces 'application/json'
      security [{ Bearer: [] }]
      parameter name: :page, in: :query, type: :integer, required: false
      let(:Authorization) { "Bearer #{regular_user_token}" }
      let(:page) { 1 }

      response '200', 'returns a paginated list of actions' do
        schema envelope_schema({ actions: list(:UserAction) }, meta: true)
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}/update_location' do
    parameter name: :id, in: :path, type: :integer
    let(:id) { regular_user.id }

    patch "Updates the user's location" do
      tags 'Users'
      consumes 'application/json'
      produces 'application/json'
      security [{ Bearer: [] }]
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { location: { type: :object, properties: { country: { type: :string }, city: { type: :string },
                                                               street: { type: :string },
                                                               postal_code: { type: :string } } } },
        required: ['location']
      }
      let(:Authorization) { "Bearer #{regular_user_token}" }
      let(:body) { { location: { city: 'Warsaw', country: 'Poland', province: 'Mazovia', postal_code: '00-001' } } }

      response '200', 'location updated' do
        schema envelope_schema(user: ref(:UserProfile))
        run_test!
      end
    end
  end

  path '/api/v1/users/{id}/update_entrepreneur_details' do
    parameter name: :id, in: :path, type: :integer
    let!(:entrepreneur) { create(:user, :with_detail, role: :entrepreneur) }
    let(:id) { entrepreneur.id }

    patch "Updates the entrepreneur's business details" do
      tags 'Users'
      consumes 'application/json'
      produces 'application/json'
      security [{ Bearer: [] }]
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { entrepreneur_detail: { type: :object, properties: { business_name: { type: :string },
                                                                          nip: { type: :string } } } },
        required: ['entrepreneur_detail']
      }
      let(:Authorization) { "Bearer #{Auth::Bearer.encode({ user_id: entrepreneur.id }).data[:token]}" }
      let(:body) { { entrepreneur_detail: { business_name: 'Acme', nip: '1234567890' } } }

      response '200', 'details updated' do
        schema envelope_schema(user: ref(:UserProfile))
        run_test!
      end
    end
  end
end
