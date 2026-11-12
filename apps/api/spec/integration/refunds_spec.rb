# frozen_string_literal: true

require 'swagger_helper'

describe 'Refunds API' do
  let!(:admin) { create(:user, :admin, :with_detail) }
  let!(:user) { create(:user, :regular, :with_detail) }
  let!(:other_user) { create(:user, :regular, :with_detail) }
  let!(:order) { create(:order, user: user, status: :delivered, payment_status: :paid) }
  let!(:refund) { create(:refund, order: order, user: user) }
  let(:Authorization) { bearer(user) }
  let(:id) { refund.id }
  let(:refund_attributes) { { reason: 'damaged', description: 'Arrived broken' } }

  path '/api/v1/orders/{order_id}/refunds' do
    parameter name: :order_id, in: :path, type: :integer
    let(:order_id) { order.id }

    get 'Lists the refunds of an order (Admin only)' do
      tags 'Refunds'
      produces 'application/json'
      security [Bearer: []]

      response '200', 'returns the refunds of the order' do
        let(:Authorization) { bearer(admin) }
        schema envelope_schema({ refunds: list(:Refund) })
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid' }
        schema failure_schema
        run_test!
      end
    end

    post 'Requests a refund for an order' do
      tags 'Refunds'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { refund: { type: :object,
                                properties: { reason: { type: :string }, description: { type: :string } } } },
        required: ['refund']
      }
      let(:body) { { refund: refund_attributes } }

      response '201', 'refund created' do
        let!(:refund) { nil }
        schema envelope_schema(refund: ref(:Refund))
        run_test!
      end

      response '409', 'a refund has already been requested' do
        schema failure_schema
        run_test!
      end
    end
  end

  path '/api/v1/refunds/me' do
    get "Lists the current user's refunds" do
      tags 'Refunds'
      produces 'application/json'
      security [Bearer: []]

      response '200', 'returns own refunds' do
        schema envelope_schema({ refunds: list(:Refund) })
        run_test!
      end
    end
  end

  path '/api/v1/refunds/{id}' do
    parameter name: :id, in: :path, type: :integer

    get 'Retrieves a refund' do
      tags 'Refunds'
      produces 'application/json'
      security [Bearer: []]

      response '200', 'returns the refund' do
        schema envelope_schema(refund: ref(:Refund))
        run_test!
      end

      response '403', 'forbidden for another user' do
        let(:Authorization) { bearer(other_user) }
        schema failure_schema
        run_test!
      end
    end

    %i[patch put].each do |verb|
      public_send(verb, "Updates a refund (#{verb.upcase})") do
        tags 'Refunds'
        consumes 'application/json'
        produces 'application/json'
        security [Bearer: []]
        parameter name: :body, in: :body, schema: {
          type: :object,
          properties: { refund: { type: :object, properties: { status: { type: :string }, reason: { type: :string },
                                                               description: { type: :string } } } },
          required: ['refund']
        }
        let(:Authorization) { bearer(admin) }
        let(:body) { { refund: { description: 'Updated' } } }

        response '200', 'refund updated' do
          schema envelope_schema(refund: ref(:Refund))
          run_test!
        end
      end
    end

    delete 'Deletes a refund (Admin only)' do
      tags 'Refunds'
      security [Bearer: []]

      response '204', 'refund deleted' do
        let(:Authorization) { bearer(admin) }
        run_test!
      end

      response '403', 'forbidden for a regular user' do
        schema failure_schema
        run_test!
      end
    end
  end

  path '/api/v1/refunds/{id}/cancel' do
    parameter name: :id, in: :path, type: :integer

    post 'Cancels a refund' do
      tags 'Refunds'
      produces 'application/json'
      security [Bearer: []]

      response '200', 'refund cancelled' do
        schema envelope_schema(refund: ref(:Refund))
        run_test!
      end
    end
  end

  path '/api/v1/refunds/{id}/complete' do
    parameter name: :id, in: :path, type: :integer

    post 'Completes a refund (Admin only)' do
      tags 'Refunds'
      produces 'application/json'
      security [Bearer: []]
      let(:Authorization) { bearer(admin) }

      response '200', 'refund completed' do
        let!(:refund) { create(:refund, :processing, order: order, user: user) }
        before do
          create(:payment, :paid, order: order)
          allow(Stripe::Refund).to receive(:create).and_return(double(id: 're_1'))
        end
        schema envelope_schema(refund: ref(:Refund))
        run_test!
      end

      response '422', 'order has no paid payment' do
        let!(:refund) { create(:refund, :processing, order: order, user: user) }
        run_test!
      end
    end
  end
end
