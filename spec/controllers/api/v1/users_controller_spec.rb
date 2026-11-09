# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::UsersController, type: :controller do
  render_views

  let!(:admin_user) do
    user = create(:user, :admin, :with_detail)
    create(:location, user_detail: user.user_detail)
    user
  end
  let!(:regular_user) do
    user = create(:user, :regular, :with_detail)
    create(:location, user_detail: user.user_detail)
    user
  end
  let!(:other_user) do
    user = create(:user, :regular, :with_detail)
    create(:location, user_detail: user.user_detail)
    user
  end

  let(:user_creation_service) { instance_double(Services::UserCreationService) }
  let(:user_profile_service) { instance_double(Services::UserProfileService) }
  let(:authentication_service) { instance_double(Services::AuthenticationService) }

  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:user_profile_service).and_return(user_profile_service)
    newly_created_user = build_stubbed(:user)
    allow(newly_created_user).to receive(:user_detail).and_return(nil)

    allow(Services::UserCreationService).to receive(:call).and_return(
      Services::Result.new(success?: true, data: { user: newly_created_user }, status: :created)
    )
  end

  describe 'POST #create' do
    let(:user_params) { { user: attributes_for(:user, :with_detail) } }

    it 'calls UserCreationService with user_params' do
      post :create, params: user_params, format: :json
      expect(Services::UserCreationService).to have_received(:call)
    end

    it 'returns a created status on success' do
      post :create, params: user_params, format: :json
      expect(response).to have_http_status(:created)
    end
  end

  describe 'GET #show' do
    context 'when user is an admin' do
      before { allow(controller).to receive(:current_user).and_return(admin_user) }

      it 'allows access to another user profile' do
        get :show, params: { id: other_user.id }, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['user']['id']).to eq(other_user.id)
      end
    end

    context 'when user is the profile owner' do
      before { allow(controller).to receive(:current_user).and_return(regular_user) }

      it 'allows access to their own profile' do
        get :show, params: { id: regular_user.id }, format: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when user is not the owner and not an admin' do
      before { allow(controller).to receive(:current_user).and_return(regular_user) }

      it 'returns forbidden status' do
        get :show, params: { id: other_user.id }, format: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET #me' do
    context 'when user is authenticated' do
      before { allow(controller).to receive(:current_user).and_return(regular_user) }

      it 'returns the current user profile' do
        get :me, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['user']['id']).to eq(regular_user.id)
      end
    end

    context 'when user is not authenticated' do
      it 'triggers authenticate_user! before_action' do
        expect(controller).to receive(:authenticate_user!).and_call_original
        get :me, format: :json
        expect(response).not_to have_http_status(:ok)
      end
    end
  end

  describe 'PATCH #update' do
    let(:update_params) { { id: regular_user.id, user: { mail: 'new@example.com' } } }

    before do
      allow(user_profile_service).to receive(:update_profile).and_return(
        Services::Result.new(success?: true, data: { user: regular_user }, status: :ok)
      )
    end

    context 'when user is the profile owner' do
      before { allow(controller).to receive(:current_user).and_return(regular_user) }

      it 'calls the profile service to update the profile' do
        patch :update, params: update_params, format: :json
        expect(user_profile_service).to have_received(:update_profile)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when user is not the owner' do
      before { allow(controller).to receive(:current_user).and_return(other_user) }

      it 'returns forbidden status' do
        patch :update, params: update_params, format: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET #index' do
    context 'as an admin' do
      before { allow(controller).to receive(:current_user).and_return(admin_user) }

      it 'returns a list of users' do
        get :index, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['users'].size).to be >= 3
      end
    end

    context 'as a regular user' do
      before { allow(controller).to receive(:current_user).and_return(regular_user) }

      it 'returns forbidden status' do
        get :index, format: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH #role' do
    let(:role_params) { { id: regular_user.id, role: 'moderator' } }

    before do
      allow(user_profile_service).to receive(:update_role).and_return(
        Services::Result.new(success?: true, data: { user: regular_user }, status: :ok)
      )
    end

    context 'as an admin' do
      before { allow(controller).to receive(:current_user).and_return(admin_user) }

      it 'updates the user role' do
        patch :role, params: role_params, format: :json
        expect(user_profile_service).to have_received(:update_role).with('moderator')
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as a regular user' do
      before { allow(controller).to receive(:current_user).and_return(regular_user) }

      it 'returns forbidden status' do
        patch :role, params: role_params, format: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST #logout' do
    before do
      allow(Services::AuthenticationService).to receive(:blacklist_token).and_return(
        Services::Result.new(success?: true, status: :ok, message: 'Successfully logged out.')
      )
      request.headers['Authorization'] = 'Bearer test_token'
    end

    context 'as an authenticated user' do
      before { allow(controller).to receive(:current_user).and_return(regular_user) }

      it 'calls the blacklist_token service' do
        post :logout, format: :json
        expect(Services::AuthenticationService).to have_received(:blacklist_token).with('test_token')
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'GET #actions' do
    let!(:action) { create(:user_action, user: regular_user) }

    context 'as an admin' do
      before { allow(controller).to receive(:current_user).and_return(admin_user) }

      it "returns other user's actions" do
        get :actions, params: { id: regular_user.id }, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['actions'].first['id']).to eq(action.id)
      end
    end

    context 'as the profile owner' do
      before { allow(controller).to receive(:current_user).and_return(regular_user) }

      it 'returns their own actions' do
        get :actions, params: { id: regular_user.id }, format: :json
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
