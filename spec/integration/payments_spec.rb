# frozen_string_literal: true

require 'swagger_helper'

describe 'Payments API' do
  let!(:regular_user) { create(:user) }
  let(:regular_user_token) { Services::BearerService.encode({ user_id: regular_user.id }).data[:token] }
  let!(:admin_user) { create(:user, :admin) }
  let(:admin_user_token) { Services::BearerService.encode({ user_id: admin_user.id }).data[:token] }
  let!(:other_user) { create(:user) }

  before do
    allow_any_instance_of(CartObserver).to receive(:after_create).and_return(true)
  end

  path '/api/v1/payments' do
    get 'Lists payments (Admin Only)' do
      tags 'Payments'
      produces 'application/json'
      security [Bearer: []]

      context 'as an admin user' do
        let(:Authorization) { "Bearer #{admin_user_token}" }
        response '200', 'returns all payments' do
          schema type: :object, properties: {
            payments: { type: :array, items: { '$ref' => '#/components/schemas/Payment' } }
          }
          before do
            order1 = create(:order, user: regular_user)
            order2 = create(:order, user: other_user)
            create(:payment, order: order1)
            create(:payment, order: order2)
          end
          run_test!
        end
      end
    end

    post 'Creates a payment' do
      tags 'Payments'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :payment_params, in: :body, schema: {
        type: :object,
        properties: {
          payment: {
            type: :object,
            properties: { order_id: { type: :integer, description: 'ID of the order to pay for' } },
            required: ['order_id']
          }
        }
      }
      let(:Authorization) { "Bearer #{regular_user_token}" }

      context 'with a valid order' do
        let!(:order) { create(:order, :with_items, user: regular_user) }
        let(:payment_params) { { payment: { order_id: order.id } } }

        response '201', 'payment initiated successfully' do
          schema '$ref' => '#/components/schemas/Payment'

          before do
            allow(Services::PaymentCreationService).to receive(:call).and_return(
              Services::Result.new(success?: true, status: :created,
                                   data: { payment: create(:payment, :paid, order: order) })
            )
          end
          run_test!
        end
      end

      context 'with an order belonging to another user' do
        response '404', 'order not found' do
          let!(:other_order) { create(:order, user: other_user) }
          let(:payment_params) { { payment: { order_id: other_order.id } } }
          run_test!
        end
      end
    end
  end

  path '/api/v1/payments/{id}' do
    get 'Retrieves a single payment' do
      tags 'Payments'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :id, in: :path, type: :integer, required: true

      let!(:order) { create(:order, user: regular_user) }
      let!(:payment) { create(:payment, order: order) }
      let(:id) { payment.id }

      context 'as the payment owner' do
        let(:Authorization) { "Bearer #{regular_user_token}" }
        response '200', 'returns the requested payment' do
          schema '$ref' => '#/components/schemas/Payment'
          run_test!
        end
      end

      context 'as an admin' do
        let(:Authorization) { "Bearer #{admin_user_token}" }
        response '200', 'returns the requested payment' do
          run_test!
        end
      end

      context 'as another user (not owner)' do
        let(:another_user_token) { Services::BearerService.encode({ user_id: other_user.id }).data[:token] }
        let(:Authorization) { "Bearer #{another_user_token}" }
        response '403', 'forbidden' do
          run_test!
        end
      end
    end
  end
end
