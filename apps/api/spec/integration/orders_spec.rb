# frozen_string_literal: true

require 'swagger_helper'

describe 'Orders API' do
  let!(:regular_user) { create(:user, :with_location) }
  let(:regular_user_token) { Auth::Bearer.encode({ user_id: regular_user.id }).data[:token] }
  let!(:admin_user) { create(:user, :admin) }
  let(:admin_user_token) { Auth::Bearer.encode({ user_id: admin_user.id }).data[:token] }
  let!(:other_user) { create(:user) }

  before do
    allow(OrderObserver.instance).to receive(:after_create).and_return(true)
    allow(OrderObserver.instance).to receive(:after_update).and_return(true)
    allow(OrderObserver.instance).to receive(:after_destroy).and_return(true)
    allow_any_instance_of(CartObserver).to receive(:after_create).and_return(true)
    allow_any_instance_of(CartObserver).to receive(:after_update).and_return(true)
    allow_any_instance_of(CartObserver).to receive(:after_destroy).and_return(true)
    allow_any_instance_of(UserObserver).to receive(:after_create).and_return(true)
    allow_any_instance_of(UserObserver).to receive(:after_update).and_return(true)
    allow_any_instance_of(UserObserver).to receive(:after_destroy).and_return(true)
    allow_any_instance_of(ProductObserver).to receive(:after_create).and_return(true)
    allow_any_instance_of(ProductObserver).to receive(:after_update).and_return(true)
    allow_any_instance_of(ProductObserver).to receive(:after_destroy).and_return(true)
  end

  path '/api/v1/orders' do
    get 'Lists orders' do
      tags 'Orders'
      produces 'application/json'
      security [Bearer: []]

      let(:schema) do
        {
          type: :object,
          properties: {
            orders: {
              type: :array,
              items: { '$ref' => '#/components/schemas/Order' }
            }
          },
          required: ['orders']
        }
      end

      context 'as an admin user' do
        let(:Authorization) { "Bearer #{admin_user_token}" }
        response '200', 'returns all orders' do
          before do
            create(:order, user: regular_user)
            create(:order, user: other_user)
          end
          run_test!
        end
      end

      context 'as a regular user' do
        let(:Authorization) { "Bearer #{regular_user_token}" }
        response '200', 'returns only own orders' do
          before do
            create(:order, user: regular_user)
            create(:order, user: other_user)
          end
          run_test!
        end
      end
    end
  end

  path '/api/v1/orders/me' do
    get "Lists current user's orders" do
      tags 'Orders'
      produces 'application/json'
      security [Bearer: []]
      let(:Authorization) { "Bearer #{regular_user_token}" }

      response '200', 'returns current user orders' do
        schema type: :object, properties: {
          orders: { type: :array, items: { '$ref' => '#/components/schemas/Order' } }
        }
        before { create_list(:order, 2, user: regular_user) }
        run_test!
      end
    end
  end

  path '/api/v1/orders/{id}' do
    let!(:order) { create(:order, :with_items, user: regular_user) }
    let(:id) { order.id }

    get 'Retrieves a single order' do
      tags 'Orders'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :id, in: :path, type: :integer, required: true

      context 'as the order owner' do
        let(:Authorization) { "Bearer #{regular_user_token}" }
        response '200', 'returns the requested order' do
          schema '$ref' => '#/components/schemas/Order'
          run_test!
        end
      end

      context 'as an admin' do
        let(:Authorization) { "Bearer #{admin_user_token}" }
        response '200', 'returns the requested order' do
          schema '$ref' => '#/components/schemas/Order'
          run_test!
        end
      end

      context 'as another user (not owner)' do
        let(:another_user_token) { Auth::Bearer.encode({ user_id: other_user.id }).data[:token] }
        let(:Authorization) { "Bearer #{another_user_token}" }
        response '403', 'forbidden' do
          run_test!
        end
      end
    end

    put 'Updates an order (Admin only)' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :order_params, in: :body, schema: {
        type: :object,
        properties: {
          order: {
            type: :object,
            properties: {
              status: { type: :string, example: 'shipped' },
              payment_status: { type: :string, example: 'paid' }
            }
          }
        }
      }
      let(:order_params) { { order: { status: 'shipped' } } }

      context 'as an admin' do
        let(:Authorization) { "Bearer #{admin_user_token}" }
        response '200', 'order updated successfully' do
          schema '$ref' => '#/components/schemas/Order'
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

    delete 'Deletes an order (Admin only)' do
      tags 'Orders'
      security [Bearer: []]
      parameter name: :id, in: :path, type: :integer, required: true

      context 'as an admin' do
        let(:Authorization) { "Bearer #{admin_user_token}" }
        response '204', 'order deleted successfully' do
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

  path '/api/v1/orders' do
    post 'Creates an order from cart items' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          order: {
            type: :object,
            properties: {
              cart_item_ids: { type: :array, items: { type: :integer } }
            }
          }
        }
      }

      let(:Authorization) { "Bearer #{regular_user_token}" }
      let!(:cart_item1) { create(:cart_item, user: regular_user) }
      let!(:cart_item2) { create(:cart_item, user: regular_user) }
      let(:params) { { order: { cart_item_ids: [cart_item1.id, cart_item2.id] } } }

      response '201', 'order created successfully' do
        schema '$ref' => '#/components/schemas/Order'
        run_test!
      end
    end
  end

  path '/api/v1/orders/{id}/cancel' do
    post 'Cancels an order' do
      tags 'Orders'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :id, in: :path, type: :integer, required: true

      let!(:order) { create(:order, user: regular_user) }
      let(:id) { order.id }
      let(:Authorization) { "Bearer #{regular_user_token}" }

      response '200', 'order cancelled' do
        schema '$ref' => '#/components/schemas/Order'
        run_test!
      end
    end
  end
end
