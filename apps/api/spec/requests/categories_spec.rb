# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Categories', type: :request do
  let(:json) { JSON.parse(response.body) }

  let(:admin) { create(:user, :admin, :with_detail) }
  let(:user) { create(:user, :regular, :with_detail) }
  let!(:category) { Category.create!(name: 'Tools') }

  def headers_for(actor)
    {
      'Authorization' => "Bearer #{Auth::Bearer.encode({ user_id: actor.id }).data[:token]}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  describe 'GET /api/v1/categories' do
    it 'lists the categories' do
      get '/api/v1/categories', headers: headers_for(user)

      expect(response).to have_http_status(:ok)
      expect(json['data']['categories'].map { |entry| entry['name'] }).to include('Tools')
    end
  end

  describe 'POST /api/v1/categories' do
    it 'creates a category as an admin' do
      expect do
        post '/api/v1/categories', params: { category: { name: 'Garden' } }.to_json, headers: headers_for(admin)
      end.to change(Category, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json['data']['category']['name']).to eq('Garden')
    end

    it 'is forbidden for a regular user' do
      post '/api/v1/categories', params: { category: { name: 'Garden' } }.to_json, headers: headers_for(user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /api/v1/categories/:id' do
    it 'renames a category as an admin' do
      patch "/api/v1/categories/#{category.id}",
            params: { category: { name: 'Power tools' } }.to_json, headers: headers_for(admin)

      expect(response).to have_http_status(:ok)
      expect(category.reload.name).to eq('Power tools')
    end
  end

  describe 'DELETE /api/v1/categories/:id' do
    it 'deletes a category as an admin' do
      expect do
        delete "/api/v1/categories/#{category.id}", headers: headers_for(admin)
      end.to change(Category, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
