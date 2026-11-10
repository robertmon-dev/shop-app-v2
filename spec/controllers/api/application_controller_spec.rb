# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::ApplicationController, type: :controller do
  controller do
    def self.controller_path
      'api/application'
    end

    rescue_from ActiveRecord::RecordNotFound do |exception|
      render json: { errors: [exception.message], message: 'Resource not found.' }, status: :not_found
    end
    rescue_from ActiveRecord::RecordInvalid do |exception|
      render json: { errors: exception.record.errors.full_messages, message: 'Validation failed.' },
             status: :unprocessable_entity
    end
    rescue_from Api::ApplicationController::Forbidden do |exception|
      render json: { errors: [exception.message], message: 'Access denied.' }, status: :forbidden
    end

    def index
      render json: { message: 'success' }, status: :ok
    end

    def restricted_action
      authorize_admin!
      render json: { message: 'admin access granted' }, status: :ok
    end

    def not_found
      raise ActiveRecord::RecordNotFound, 'Resource not found'
    end

    def unprocessable
      user = User.new
      user.validate
      raise ActiveRecord::RecordInvalid, user
    end

    def forbidden
      raise Api::ApplicationController::Forbidden, 'Access denied'
    end
  end

  before do
    routes.draw do
      get 'index' => 'api/application#index'
      get 'restricted_action' => 'api/application#restricted_action'
      get 'not_found' => 'api/application#not_found'
      get 'unprocessable' => 'api/application#unprocessable'
      get 'forbidden' => 'api/application#forbidden'
    end
  end

  let!(:user) { create(:user, active: true, verified: true) }
  let(:bearer_service) { class_double(Auth::Bearer) }

  before do
    stub_const('Auth::Bearer', bearer_service)
  end

  describe 'Authentication' do
    context 'with a valid token' do
      it 'allows access to the action' do
        token_result = ApplicationService::Result.new(success?: true, data: { payload: { user_id: user.id } })
        allow(bearer_service).to receive(:decode).and_return(token_result)
        request.headers['Authorization'] = 'Bearer valid_token'
        get :index
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with no token' do
      it 'returns an unauthorized status' do
        token_result = ApplicationService::Result.new(success?: false, errors: ['Token missing'], status: :unauthorized)
        allow(bearer_service).to receive(:decode).and_return(token_result)
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with an invalid token' do
      it 'returns an unauthorized status' do
        token_result = ApplicationService::Result.new(success?: false, errors: ['Invalid token'], status: :unauthorized)
        allow(bearer_service).to receive(:decode).and_return(token_result)
        request.headers['Authorization'] = 'Bearer invalid_token'
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a valid token for a non-existent user' do
      it 'returns an unauthorized status' do
        token_result = ApplicationService::Result.new(success?: true, data: { payload: { user_id: -1 } })
        allow(bearer_service).to receive(:decode).and_return(token_result)
        request.headers['Authorization'] = 'Bearer valid_token'
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a user that is not active' do
      before { user.update!(active: false) }
      it 'returns a forbidden status' do
        token_result = ApplicationService::Result.new(success?: true, data: { payload: { user_id: user.id } })
        allow(bearer_service).to receive(:decode).and_return(token_result)
        request.headers['Authorization'] = 'Bearer valid_token'
        get :index
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'Authorization' do
    context 'when an admin accesses a restricted action' do
      let!(:admin) { create(:user, :admin, active: true, verified: true) }
      it 'allows access' do
        token_result = ApplicationService::Result.new(success?: true, data: { payload: { user_id: admin.id } })
        allow(bearer_service).to receive(:decode).and_return(token_result)
        request.headers['Authorization'] = 'Bearer admin_token'
        get :restricted_action
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when a regular user accesses a restricted action' do
      it 'returns a forbidden status' do
        token_result = ApplicationService::Result.new(success?: true, data: { payload: { user_id: user.id } })
        allow(bearer_service).to receive(:decode).and_return(token_result)
        request.headers['Authorization'] = 'Bearer user_token'
        get :restricted_action
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'Exception Handling' do
    before do
      token_result = ApplicationService::Result.new(success?: true, data: { payload: { user_id: user.id } })
      allow(bearer_service).to receive(:decode).and_return(token_result)
      request.headers['Authorization'] = 'Bearer valid_token'
    end

    it 'rescues from ActiveRecord::RecordNotFound with a 404 status' do
      get :not_found
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Resource not found.')
    end

    it 'rescues from ActiveRecord::RecordInvalid with a 422 status' do
      get :unprocessable
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Validation failed.')
    end

    it 'rescues from Forbidden with a 403 status' do
      get :forbidden
      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Access denied.')
    end
  end
end
