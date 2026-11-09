# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ProductsController, type: :controller do
  render_views

  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
  end

  let!(:user) { create(:user, :with_detail, role: :regular) }
  let!(:admin) { create(:user, :with_detail, role: :admin) }
  let!(:moderator) { create(:user, :with_detail, role: :moderator) }

  let!(:product) { create(:product) }
  let(:product_creation_service) { instance_double(Services::ProductCreationService) }
  let(:product_update_service) { instance_double(Services::ProductUpdateService) }
  let(:product_deletion_service) { instance_double(Services::ProductDeletionService) }
  let(:product_interaction_service) { instance_double(Services::ProductInteractionService) }

  let(:product_likes_collection) { instance_double('ActiveRecord::Relation', count: 1, maximum: Time.current) }
  let(:comments_collection) { instance_double('ActiveRecord::Relation', count: 0, where: [], maximum: Time.current) }
  let(:product_photos_collection) { instance_double('ActiveRecord::Relation', maximum: Time.current) }

  before do
    allow(product_likes_collection).to receive(:map).and_return([])
    allow(comments_collection).to receive(:map).and_return([])
    allow(product_photos_collection).to receive(:map).and_return([])

    allow(product).to receive(:product_likes).and_return(product_likes_collection)
    allow(product).to receive(:comments).and_return(comments_collection)
    allow(product).to receive(:product_photos).and_return(product_photos_collection)

    allow(product).to receive(:product_rates).and_return(double('product_rates', count: 1))

    allow(Services::ProductCreationService).to receive(:call).and_return(
      Services::Result.new(success?: true, data: { product: product }, status: :created,
                           message: 'Product created successfully.')
    )
    allow(Services::ProductUpdateService).to receive(:call).and_return(
      Services::Result.new(success?: true, data: { product: product }, status: :ok,
                           message: 'Product updated successfully.')
    )
    allow(Services::ProductDeletionService).to receive(:call).and_return(
      Services::Result.new(success?: true, data: {}, status: :no_content, message: 'Product deleted successfully.')
    )
    allow(controller).to receive(:product_interaction_service).and_return(product_interaction_service)
    allow(product_interaction_service).to receive(:like).and_return(
      Services::Result.new(success?: true, data: { product: product }, status: :ok,
                           message: 'Product liked successfully.')
    )
    allow(product_interaction_service).to receive(:rate).and_return(
      Services::Result.new(success?: true, data: { product: product }, status: :ok,
                           message: 'Product rated successfully.')
    )
    allow(product_interaction_service).to receive(:add_comment).and_return(
      Services::Result.new(success?: true, data: { product: product }, status: :created,
                           message: 'Comment added successfully.')
    )

    allow(Services::ProductCachingService).to receive(:fetch_one).and_return(
      Services::Result.new(success?: true, data: { product: product }, status: :ok,
                           message: 'Product has been found')
    )
  end

  describe 'GET #index' do
    before do
      paginated_double = double('paginated_collection')
      allow(paginated_double).to receive_messages(
        current_page: 1,
        total_pages: 1,
        limit_value: 25,
        total_count: 1,
        next_page: nil,
        prev_page: nil
      )
      allow(paginated_double).to receive(:each).and_yield(product)
      allow(paginated_double).to receive(:map).and_return([product.id])
      allow(paginated_double).to receive(:maximum).with(:updated_at).and_return(product.updated_at)

      allow(Services::ProductCachingService).to receive(:fetch_all).and_return(paginated_double)
    end

    it 'returns a paginated list of products' do
      products_relation = Product.where(id: product.id)
      allow(Services::ProductCachingService).to receive(:fetch_all).and_return(products_relation)
      get :index, format: :json
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['products']).not_to be_empty
    end
  end

  describe 'GET #show' do
    context 'when product is found' do
      it 'returns a single product' do
        get :show, params: { id: product.id }, format: :json
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['product']['id']).to eq(product.id)
      end
    end

    context 'when product is not found' do
      before do
        allow(Services::ProductCachingService).to receive(:fetch_one).and_return(
          Services::Result.new(success?: false, errors: ['Product not found'], status: :not_found,
                               message: 'Product not found')
        )
      end

      it 'returns not found status' do
        get :show, params: { id: 999 }, format: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) { { product: { name: 'New Product', price: 100 } } }

    context 'as an admin' do
      before { allow(controller).to receive(:current_user).and_return(admin) }

      it 'creates a product' do
        post :create, params: valid_params, format: :json
        expect(response).to have_http_status(:created)
      end
    end

    context 'as a regular user' do
      before { allow(controller).to receive(:current_user).and_return(user) }

      it 'returns forbidden status' do
        post :create, params: valid_params, format: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PUT #update' do
    let(:valid_params) { { product: { name: 'Updated Product' } } }

    context 'as an admin' do
      before { allow(controller).to receive(:current_user).and_return(admin) }

      it 'updates a product' do
        put :update, params: { id: product.id }.merge(valid_params), format: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as a regular user' do
      before { allow(controller).to receive(:current_user).and_return(user) }

      it 'returns forbidden status' do
        put :update, params: { id: product.id }.merge(valid_params), format: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'as an admin' do
      before { allow(controller).to receive(:current_user).and_return(admin) }

      it 'deletes a product' do
        delete :destroy, params: { id: product.id }, format: :json
        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe 'POST #like' do
    it 'allows a user to like a product' do
      allow(controller).to receive(:current_user).and_return(user)
      post :like, params: { id: product.id }, format: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #rate' do
    let(:valid_params) { { product_rating: { rating: 4, comment: 'Great product!' } } }

    it 'allows a user to rate a product' do
      allow(controller).to receive(:current_user).and_return(user)
      post :rate, params: { id: product.id }.merge(valid_params), format: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #comment' do
    let(:valid_params) { { product_comment: { content: 'Nice!' } } }

    it 'allows a user to comment on a product' do
      allow(controller).to receive(:current_user).and_return(user)
      post :comment, params: { id: product.id }.merge(valid_params), format: :json
      expect(response).to have_http_status(:created)
    end
  end
end
