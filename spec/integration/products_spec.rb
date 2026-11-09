# frozen_string_literal: true

require 'swagger_helper'

describe 'Products API' do
  let!(:regular_user) { create(:user) }
  let(:regular_user_token) { Services::BearerService.encode({ user_id: regular_user.id }).data[:token] }
  let!(:admin_user) { create(:user, :admin) }
  let(:admin_user_token) { Services::BearerService.encode({ user_id: admin_user.id }).data[:token] }

  before do
    allow_any_instance_of(ProductObserver).to receive(:after_create).and_return(true)
    allow_any_instance_of(ProductObserver).to receive(:after_update).and_return(true)
    allow_any_instance_of(ProductObserver).to receive(:after_destroy).and_return(true)
    allow_any_instance_of(UserObserver).to receive(:after_create).and_return(true)
    allow_any_instance_of(UserObserver).to receive(:after_update).and_return(true)
    allow_any_instance_of(UserObserver).to receive(:after_destroy).and_return(true)
  end

  path '/api/v1/products' do
    get 'Lists all products' do
      tags 'Products'
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number for pagination'

      response '200', 'products list' do
        schema type: :object,
               properties: {
                 products: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/Product' }
                 },
                 meta: {
                   type: :object,
                   properties: {
                     current_page: { type: :integer },
                     next_page: { type: :integer, nullable: true },
                     prev_page: { type: :integer, nullable: true },
                     total_pages: { type: :integer },
                     total_count: { type: :integer }
                   },
                   required: %w[current_page total_pages total_count]
                 }
               },
               required: %w[products meta]
        before { create_list(:product, 3) }
        run_test!
      end
    end

    post 'Creates a product (Admin/Moderator only)' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :product_params, in: :body, schema: {
        type: :object,
        properties: {
          product: {
            type: :object,
            properties: {
              name: { type: :string, example: 'New Awesome Gadget' },
              price: { type: :number, example: 199.99 },
              vat_rate: { type: :number, example: 0.23 },
              weight_kg: { type: :number, example: 1.5 },
              height_cm: { type: :number, example: 10.0 },
              width_cm: { type: :number, example: 10.0 },
              length_cm: { type: :number, example: 10.0 },
              description: { type: :string, example: 'The best gadget you have ever seen.' }
            },
            required: %w[name price vat_rate weight_kg height_cm width_cm length_cm]
          }
        }
      }

      context 'as an admin' do
        let(:Authorization) { "Bearer #{admin_user_token}" }
        let(:product_params) do
          { product: { name: 'Admin Product', price: 100, vat_rate: 0.23, weight_kg: 1.5, height_cm: 10, width_cm: 10,
                       length_cm: 10 } }
        end
        response '201', 'product created' do
          schema type: :object,
                 properties: { product: { '$ref' => '#/components/schemas/Product' } },
                 required: ['product']
          run_test!
        end
      end

      context 'as a regular user' do
        let(:Authorization) { "Bearer #{regular_user_token}" }
        let(:product_params) do
          { product: { name: 'User Product', price: 100, vat_rate: 0.23, weight_kg: 1.5, height_cm: 10, width_cm: 10,
                       length_cm: 10 } }
        end
        response '403', 'forbidden' do
          run_test!
        end
      end
    end
  end

  path '/api/v1/products/{id}' do
    let!(:product) { create(:product) }
    let(:id) { product.id }

    get 'Retrieves a single product' do
      tags 'Products'
      produces 'application/json'
      parameter name: :id, in: :path, type: :string, format: :uuid, required: true

      response '200', 'product found' do
        schema type: :object,
               properties: { product: { '$ref' => '#/components/schemas/Product' } },
               required: ['product']
        run_test!
      end

      response '404', 'product not found' do
        let(:id) { 'invalid-uuid' }
        run_test!
      end
    end

    put 'Updates a product (Admin/Moderator only)' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :id, in: :path, type: :string, format: :uuid, required: true
      parameter name: :product_params, in: :body, schema: {
        type: :object,
        properties: {
          product: {
            type: :object,
            properties: {
              name: { type: :string, example: 'Updated Gadget Name' },
              price: { type: :number, example: 249.99 },
              description: { type: :string, example: 'An updated description for this gadget.' }
            },
            required: []
          }
        },
        required: ['product']
      }
      let(:product_params) { { product: { name: 'Updated Name' } } }

      context 'as an admin' do
        let(:Authorization) { "Bearer #{admin_user_token}" }
        response '200', 'product updated' do
          schema type: :object,
                 properties: { product: { '$ref' => '#/components/schemas/Product' } },
                 required: ['product']
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

    delete 'Deletes a product (Admin/Moderator only)' do
      tags 'Products'
      security [Bearer: []]
      parameter name: :id, in: :path, type: :string, format: :uuid, required: true

      context 'as an admin' do
        let(:Authorization) { "Bearer #{admin_user_token}" }
        response '204', 'product deleted' do
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

  path '/api/v1/products/{id}/like' do
    post 'Likes a product' do
      tags 'Products'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :id, in: :path, type: :string, format: :uuid, required: true
      let!(:product) { create(:product) }
      let(:id) { product.id }

      context 'as an authenticated user' do
        let(:Authorization) { "Bearer #{regular_user_token}" }
        # POPRAWKA 3: Zmieniamy oczekiwany status na 201
        response '201', 'product liked successfully' do
          schema type: :object,
                 properties: { product: { '$ref' => '#/components/schemas/Product' } },
                 required: ['product']
          run_test!
        end
      end

      context 'as an unauthenticated user' do
        let(:Authorization) { '' }
        response '401', 'unauthorized' do
          run_test!
        end
      end
    end
  end

  path '/api/v1/products/{id}/rate' do
    post 'Rates a product' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :id, in: :path, type: :string, format: :uuid, required: true
      parameter name: :rating_params, in: :body, schema: {
        type: :object,
        properties: {
          product_rating: {
            type: :object,
            properties: {
              rating: { type: :integer, example: 5 },
              comment: { type: :string, example: 'Fantastic product!' }
            },
            required: ['rating']
          }
        }
      }
      let!(:product) { create(:product) }
      let(:id) { product.id }
      let(:rating_params) { { product_rating: { rating: 5, comment: 'Great!' } } }
      let(:Authorization) { "Bearer #{regular_user_token}" }

      response '201', 'product rated successfully' do
        schema type: :object,
               properties: { product: { '$ref' => '#/components/schemas/Product' } },
               required: ['product']
        run_test!
      end
    end
  end

  path '/api/v1/products/{id}/comment' do
    post 'Adds a comment to a product' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :id, in: :path, type: :string, format: :uuid, required: true
      parameter name: :comment_params, in: :body, schema: {
        type: :object,
        properties: {
          product_comment: {
            type: :object,
            properties: {
              content: { type: :string, example: 'This is a great comment.' },
              parent_id: { type: :integer, nullable: true, description: 'ID of the parent comment for a reply' }
            },
            required: ['content']
          }
        }
      }
      let!(:product) { create(:product) }
      let(:id) { product.id }
      let(:comment_params) { { product_comment: { content: 'This is a great comment.' } } }
      let(:Authorization) { "Bearer #{regular_user_token}" }

      response '201', 'comment added successfully' do
        schema type: :object,
               properties: { product: { '$ref' => '#/components/schemas/Product' } },
               required: ['product']
        run_test!
      end
    end
  end
end
