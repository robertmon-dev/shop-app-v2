# frozen_string_literal: true

json.categories @categories, partial: 'api/v1/products/product_category', as: :category
