# frozen_string_literal: true

require 'swagger_helper'

describe 'Categories API' do
  let!(:admin) { create(:user, :admin, :with_detail) }
  let!(:user) { create(:user, :regular, :with_detail) }
  let!(:category) { Category.create!(name: 'Tools') }
  let(:Authorization) { bearer(admin) }
  let(:id) { category.id }

  path '/api/v1/categories' do
    get 'Lists categories' do
      tags 'Categories'
      produces 'application/json'
      security [Bearer: []]

      response '200', 'returns all categories' do
        schema envelope_schema({ categories: list(:Category) })
        run_test!
      end
    end

    post 'Creates a category (Admin only)' do
      tags 'Categories'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :body, in: :body, schema: { '$ref' => '#/components/schemas/CategoryInput' }
      let(:body) { { category: { name: 'Garden' } } }

      response '201', 'category created' do
        schema envelope_schema(category: ref(:Category))
        run_test!
      end

      response '403', 'forbidden for a regular user' do
        let(:Authorization) { bearer(user) }
        schema failure_schema
        run_test!
      end
    end
  end

  path '/api/v1/categories/{id}' do
    parameter name: :id, in: :path, type: :string, format: :uuid

    patch 'Updates a category (Admin only)' do
      tags 'Categories'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]
      parameter name: :body, in: :body, schema: { '$ref' => '#/components/schemas/CategoryInput' }
      let(:body) { { category: { name: 'Power tools' } } }

      response '200', 'category updated' do
        schema envelope_schema(category: ref(:Category))
        run_test!
      end
    end

    delete 'Deletes a category (Admin only)' do
      tags 'Categories'
      security [Bearer: []]

      response '204', 'category deleted' do
        run_test!
      end
    end
  end
end
