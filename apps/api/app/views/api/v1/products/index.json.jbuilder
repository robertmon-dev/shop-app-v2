# frozen_string_literal: true

json.products @products, partial: 'api/v1/products/product', as: :product
