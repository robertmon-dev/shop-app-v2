# frozen_string_literal: true

require 'rails_helper'
require 'rswag/specs'

RSpec.configure do |config|
  config.openapi_root = Rails.root.join('swagger').to_s

  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'API V1',
        version: 'v1'
      },
      paths: {},
      servers: [
        {
          url: '/'
        }
      ],
      components: {
        securitySchemes: {
          Bearer: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT',
            description: 'JWT token for authentication. Use format: `Bearer <token>`'
          }
        },
        schemas: {
          User: {
            type: :object,
            properties: {
              id: { type: :integer },
              mail: { type: :string, format: :email },
              phone: { type: :string, nullable: true },
              role: { type: :string, enum: %w[regular moderator admin] },
              active: { type: :boolean },
              verified: { type: :boolean },
              two_factor_enabled: { type: :boolean },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            },
            required: %w[id mail role active verified]
          },
          UserDetail: {
            type: :object,
            properties: {
              name: { type: :string },
              first_name: { type: :string, nullable: true },
              last_name: { type: :string, nullable: true }
            }
          },
          Product: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              name: { type: :string },
              price: { type: :string, format: :decimal },
              description: { type: :string, nullable: true },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            },
            required: %w[id name price]
          },
          ProductPhoto: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              product_id: { type: :string, format: :uuid },
              url: { type: :string, format: :uri, description: 'URL to the attached image' }
            }
          },
          Item: {
            type: :object,
            properties: {
              id: { type: :integer },
              quantity: { type: :integer },
              price_at_purchase: { type: :string, format: :decimal },
              product: { '$ref' => '#/components/schemas/Product' }
            }
          },
          Cart: {
            type: :object,
            properties: {
              items: { type: :array, items: { '$ref' => '#/components/schemas/Item' } },
              total_amount: { type: :string, format: :decimal },
              items_count: { type: :integer }
            }
          },
          Order: {
            type: :object,
            properties: {
              id: { type: :integer },
              user_id: { type: :integer },
              total_amount: { type: :string, format: :decimal },
              status: { type: :string },
              payment_status: { type: :string },
              order_date: { type: :string, format: 'date-time' },
              items: { type: :array, items: { '$ref' => '#/components/schemas/Item' } }
            }
          },
          Payment: {
            type: :object,
            properties: {
              id: { type: :integer },
              order_id: { type: :integer },
              amount: { type: :string, format: :decimal },
              status: { type: :string },
              payment_method: { type: :string },
              transaction_id: { type: :string, nullable: true },
              currency: { type: :string },
              created_at: { type: :string, format: 'date-time' }
            }
          },
          Comment: {
            type: :object,
            properties: {
              id: { type: :integer },
              content: { type: :string },
              user_id: { type: :integer },
              product_id: { type: :string, format: :uuid },
              parent_id: { type: :integer, nullable: true },
              replies_count: { type: :integer },
              created_at: { type: :string, format: 'date-time' }
            }
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
