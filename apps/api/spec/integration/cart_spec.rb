# frozen_string_literal: true

require 'swagger_helper'

describe 'Cart API' do
  let!(:user) { create(:user) }
  let(:token) { Auth::Bearer.encode({ user_id: user.id }).data[:token] }
  let(:Authorization) { "Bearer #{token}" }

  path '/api/v1/cart' do
    get 'Displays the current user cart' do
      tags 'Cart'
      produces 'application/json'
      security [Bearer: []]

      response '200', 'cart displayed' do
        schema '$ref' => '#/components/schemas/Cart'

        before do
          product = create(:product)
          create(:cart_item, user: user, product: product, quantity: 2)
        end

        after do |example|
          example.metadata[:response][:content] =
            { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
        end
        run_test!
      end
    end
  end

  path '/api/v1/cart/add/{product_id}' do
    post 'Adds a product to the cart' do
      tags 'Cart'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :product_id, in: :path, type: :string, format: :uuid, required: true,
                description: 'ID of the product to add'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          quantity: { type: :integer, example: 1, description: 'Quantity to add' }
        },
        required: ['quantity']
      }

      let!(:product) { create(:product) }
      let(:product_id) { product.id }
      let(:params) { { quantity: 2 } }

      response '200', 'product added, cart returned' do
        schema '$ref' => '#/components/schemas/Cart'

        after do |example|
          example.metadata[:response][:content] =
            { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
        end
        run_test!
      end

      response '422', 'invalid quantity' do
        let(:params) { { quantity: 0 } }
        run_test!
      end

      response '404', 'product not found' do
        let(:product_id) { 'invalid-uuid' }
        let(:params) { { quantity: 1 } }
        run_test!
      end
    end
  end

  path '/api/v1/cart/revoke/{item_id}' do
    delete 'Removes an item from the cart' do
      tags 'Cart'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :item_id, in: :path, type: :integer, required: true, description: 'ID of the cart item to remove'

      let!(:product) { create(:product) }
      let!(:cart_item) { create(:cart_item, user: user, product: product) }
      let(:item_id) { cart_item.id }

      response '200', 'item removed, cart returned' do
        schema '$ref' => '#/components/schemas/Cart'

        after do |example|
          example.metadata[:response][:content] =
            { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
        end
        run_test!
      end

      response '404', 'item not found' do
        let(:item_id) { -1 }
        run_test!
      end
    end
  end

  path '/api/v1/cart/clear' do
    delete 'Clears all items from the cart' do
      tags 'Cart'
      produces 'application/json'
      security [Bearer: []]

      response '200', 'cart cleared, empty cart returned' do
        schema '$ref' => '#/components/schemas/Cart'

        before do
          product = create(:product)
          create(:cart_item, user: user, product: product)
        end

        after do |example|
          example.metadata[:response][:content] =
            { 'application/json' => { example: JSON.parse(response.body, symbolize_names: true) } }
        end
        run_test!
      end
    end
  end
end
