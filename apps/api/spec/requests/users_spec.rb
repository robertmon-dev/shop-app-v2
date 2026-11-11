# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Users', type: :request do
  let(:json) { JSON.parse(response.body) }

  let(:admin) { create(:user, :admin, :with_detail) }
  let(:user) { create(:user, :regular, :with_detail) }
  let(:other_user) { create(:user, :regular, :with_detail) }

  let(:admin_headers) do
    {
      'Authorization' => "Bearer #{token_for(admin)}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end
  let(:user_headers) do
    {
      'Authorization' => "Bearer #{token_for(user)}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end
  let(:public_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  def token_for(user)
    Auth::Bearer.encode({ user_id: user.id }).data[:token]
  end

  describe 'POST /api/v1/users' do
    let(:valid_params) { { user: attributes_for(:user) }.to_json }

    context 'when creation is successful' do
      before do
        successful_result = ApplicationService::Result.new(success?: true, data: { user: user }, status: :created)
        allow(Users::Creation).to receive(:call).and_return(successful_result)
      end

      it 'creates a user and returns a 201 status' do
        post '/api/v1/users', params: valid_params, headers: public_headers
        expect(response).to have_http_status(:created)
      end
    end

    context 'when creation fails' do
      before do
        failed_result = ApplicationService::Result.new(success?: false, errors: ['Email has already been taken'],
                                             status: :unprocessable_content)
        allow(Users::Creation).to receive(:call).and_return(failed_result)
      end

      it 'returns a 422 status with errors' do
        post '/api/v1/users', params: valid_params, headers: public_headers
        expect(response).to have_http_status(:unprocessable_content)
        expect(json['errors']).to include('Email has already been taken')
      end
    end
  end

  describe 'GET /api/v1/users' do
    context 'as an admin' do
      it 'returns a paginated list of all users' do
        get '/api/v1/users', headers: admin_headers
        expect(response).to have_http_status(:ok)
        expect(json['data']).to have_key('users')
        expect(json).to have_key('meta')
      end
    end

    context 'as a regular user' do
      it 'is forbidden' do
        get '/api/v1/users', headers: user_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /api/v1/users/me' do
    it 'returns the current user profile' do
      get '/api/v1/users/me', headers: user_headers
      expect(response).to have_http_status(:ok)
      expect(json['data']['user']['id']).to eq(user.id)
    end

    it 'returns unauthorized if no token is provided' do
      get '/api/v1/users/me'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/users/logout' do
    it 'blacklists the token and returns a success message' do
      successful_result = ApplicationService::Result.new(success?: true, message: 'Successfully logged out', status: :ok)
      allow(Auth::Authentication).to receive(:blacklist_token).and_return(successful_result)

      post '/api/v1/users/logout', headers: user_headers
      expect(response).to have_http_status(:ok)
      expect(json['message']).to eq('Successfully logged out')
    end
  end

  describe 'Member actions for /api/v1/users/:id' do
    let(:user_profile_service) { instance_double(Users::Profile) }

    before do
      allow(Users::Profile).to receive(:new).with(an_instance_of(User)).and_return(user_profile_service)
    end

    describe 'GET /api/v1/users/:id' do
      context 'as the user themselves' do
        it 'returns their own profile' do
          get "/api/v1/users/#{user.id}", headers: user_headers
          expect(response).to have_http_status(:ok)
          expect(json['data']['user']['id']).to eq(user.id)
        end
      end

      context 'as another regular user' do
        it 'is forbidden' do
          get "/api/v1/users/#{other_user.id}", headers: user_headers
          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'as an admin' do
        it "can view another user's profile" do
          get "/api/v1/users/#{user.id}", headers: admin_headers
          expect(response).to have_http_status(:ok)
        end
      end
    end

    describe 'PATCH /api/v1/users/:id' do
      let(:update_params) { { user: { user_detail_attributes: { first_name: 'Jane' } } }.to_json }

      context 'as the user themselves' do
        it 'updates their profile' do
          successful_result = ApplicationService::Result.new(success?: true, data: { user: user }, status: :ok)
          allow(user_profile_service).to receive(:update_profile).and_return(successful_result)

          patch "/api/v1/users/#{user.id}", headers: user_headers, params: update_params
          expect(response).to have_http_status(:ok)
        end
      end

      context 'as an admin' do
        it "updates another user's profile" do
          successful_result = ApplicationService::Result.new(success?: true, data: { user: user }, status: :ok)
          allow(user_profile_service).to receive(:update_profile).and_return(successful_result)

          patch "/api/v1/users/#{user.id}", headers: admin_headers, params: update_params
          expect(response).to have_http_status(:ok)
        end
      end
    end

    describe 'PATCH /api/v1/users/:id/role/update' do
      let(:role_params) { { role: 'moderator' }.to_json }

      context 'as an admin' do
        it "updates a user's role" do
          successful_result = ApplicationService::Result.new(success?: true, data: { user: user }, status: :ok)
          allow(user_profile_service).to receive(:update_role).with('moderator').and_return(successful_result)

          patch "/api/v1/users/#{user.id}/role/update", headers: admin_headers, params: role_params
          expect(response).to have_http_status(:ok)
        end
      end

      context 'as a regular user' do
        it 'is forbidden' do
          patch "/api/v1/users/#{user.id}/role/update", headers: user_headers, params: role_params
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    describe 'DELETE /api/v1/users/:id' do
      context 'as the user themselves' do
        it 'deletes their own account' do
          successful_result = ApplicationService::Result.new(success?: true, status: :no_content)
          allow(user_profile_service).to receive(:destroy_user).and_return(successful_result)

          delete "/api/v1/users/#{user.id}", headers: user_headers
          expect(response).to have_http_status(:no_content)
        end
      end

      context 'as an admin' do
        it "deletes another user's account" do
          successful_result = ApplicationService::Result.new(success?: true, status: :no_content)
          allow(user_profile_service).to receive(:destroy_user).and_return(successful_result)

          delete "/api/v1/users/#{user.id}", headers: admin_headers
          expect(response).to have_http_status(:no_content)
        end
      end
    end
  end
end
