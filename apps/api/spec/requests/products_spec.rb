# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Products', type: :request do
  let(:json) { JSON.parse(response.body) }

  let(:admin) { create(:user, :admin, :with_detail) }
  let(:user) { create(:user, :regular, :with_detail) }

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

  let(:public_headers) { { 'Accept' => 'application/json' } }
  let!(:product) { create(:product) }

  def token_for(user)
    Auth::Bearer.encode({ user_id: user.id }).data[:token]
  end

  describe 'GET /api/v1/products' do
    it 'returns a list of products' do
      products_relation = Product.where(id: product.id)

      allow(Products::Caching).to receive(:fetch_all).and_return(products_relation)

      get '/api/v1/products', headers: public_headers

      expect(response).to have_http_status(:ok)
      expect(json['data']['products'].size).to eq(1)
      expect(json['data']['products'].first['id']).to eq(product.id)
      expect(json['meta']['total_count']).to eq(1)
    end
  end

  describe 'GET /api/v1/products/:id' do
    context 'when product exists' do
      it 'returns the product' do
        allow(Products::Caching).to receive(:fetch_one).with(product.id.to_s).and_return(
          ApplicationService::Result.new(success?: true, data: { product: product }, status: :ok,
                               message: 'Product has been found')
        )

        get "/api/v1/products/#{product.id}"
        expect(response).to have_http_status(:ok)
        expect(json['data']['product']['id']).to eq(product.id)
      end
    end

    context 'when product does not exist' do
      it 'returns a not found error' do
        allow(Products::Caching).to receive(:fetch_one).with('non-existent').and_return(
          ApplicationService::Result.new(success?: false, errors: ['Product not found'], status: :not_found,
                               message: 'Product not found')
        )

        get '/api/v1/products/non-existent'
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/products' do
    let(:valid_params) { { product: { name: 'New Gadget', price: 99.99 } }.to_json }

    context 'as an admin' do
      it 'creates a product when params are valid' do
        created_product = build_stubbed(:product, name: 'New Gadget', price: 99.99)
        successful_result = ApplicationService::Result.new(success?: true, data: { product: created_product }, status: :created)
        allow(Products::Creation).to receive(:call).and_return(successful_result)

        post '/api/v1/products', headers: admin_headers, params: valid_params
        expect(response).to have_http_status(:created)
        expect(json['data']['product']['name']).to eq('New Gadget')
      end

      it 'returns an error when params are invalid' do
        failed_result = ApplicationService::Result.new(success?: false, errors: ["Name can't be blank"],
                                             status: :unprocessable_content)
        allow(Products::Creation).to receive(:call).and_return(failed_result)

        post '/api/v1/products', headers: admin_headers, params: { product: { name: '' } }.to_json
        expect(response).to have_http_status(:unprocessable_content)
        expect(json['errors']).to include("Name can't be blank")
      end
    end

    context 'as a regular user' do
      it 'is forbidden' do
        post '/api/v1/products', headers: user_headers, params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH /api/v1/products/:id' do
    let(:update_params) { { product: { price: 129.99 } }.to_json }

    context 'as an admin' do
      it 'updates the product' do
        successful_result = ApplicationService::Result.new(success?: true, data: { product: product }, status: :ok)
        allow(Products::Update).to receive(:call).and_return(successful_result)

        patch "/api/v1/products/#{product.id}", headers: admin_headers, params: update_params
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as a regular user' do
      it 'is forbidden' do
        patch "/api/v1/products/#{product.id}", headers: user_headers, params: update_params
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE /api/v1/products/:id' do
    context 'as an admin' do
      it 'deletes the product' do
        successful_result = ApplicationService::Result.new(success?: true, status: :no_content)
        allow(Products::Deletion).to receive(:call).and_return(successful_result)

        delete "/api/v1/products/#{product.id}", headers: admin_headers
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'as a regular user' do
      it 'is forbidden' do
        delete "/api/v1/products/#{product.id}", headers: user_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'Product Interactions' do
    let(:interaction_service) { instance_double(Products::Interaction) }
    before do
      allow(Products::Interaction).to receive(:new).with(an_instance_of(User)).and_return(interaction_service)
    end

    describe 'POST /api/v1/products/:id/like' do
      it 'allows an authenticated user to like a product' do
        successful_result = ApplicationService::Result.new(success?: true, data: { product: product }, status: :ok)
        allow(interaction_service).to receive(:like).with(product).and_return(successful_result)

        post "/api/v1/products/#{product.id}/like", headers: user_headers
        expect(response).to have_http_status(:ok)
      end

      it 'returns unauthorized for unauthenticated users' do
        post "/api/v1/products/#{product.id}/like"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe 'POST /api/v1/products/:id/rate' do
      let(:rate_params) { { product_rating: { rating: 5, comment: 'Great!' } }.to_json }

      it 'allows an authenticated user to rate a product' do
        successful_result = ApplicationService::Result.new(success?: true, data: { product: product }, status: :ok)
        allow(interaction_service).to receive(:rate).with(product, 5, 'Great!').and_return(successful_result)

        post "/api/v1/products/#{product.id}/rate", headers: user_headers, params: rate_params
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'POST /api/v1/products/:id/comment' do
      let(:comment_params) { { product_comment: { content: 'This is a comment.' } }.to_json }

      it 'allows an authenticated user to add a comment' do
        successful_result = ApplicationService::Result.new(success?: true, data: { product: product }, status: :ok)
        allow(interaction_service).to receive(:add_comment).with(product, 'This is a comment.',
                                                                 nil).and_return(successful_result)

        post "/api/v1/products/#{product.id}/comment", headers: user_headers, params: comment_params
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'POST /api/v1/products/:id/create_photo' do
    let(:image) do
      Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
    end

    it 'attaches a photo to the product as an admin' do
      expect do
        post "/api/v1/products/#{product.id}/create_photo", params: { image: image },
                                                            headers: admin_headers.except('Content-Type')
      end.to change(ProductPhoto, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json['data']['product_photo']['id']).to be_present
    end

    it 'is forbidden for a regular user' do
      post "/api/v1/products/#{product.id}/create_photo", params: { image: image },
                                                          headers: user_headers.except('Content-Type')

      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects a request without an image' do
      post "/api/v1/products/#{product.id}/create_photo", headers: admin_headers.except('Content-Type')

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
