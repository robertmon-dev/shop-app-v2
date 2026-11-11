# frozen_string_literal: true

module Products
  class Deletion < ApplicationService
    def initialize(product)
      @product = product
    end

    def call
      return missing_result('Product') unless @product

      with_error_not_destroyed_handling do
        ActiveRecord::Base.transaction do
          @product.destroy!
          Caching.invalidate_for_product(@product)
        end
        destroy_success_result(message: 'Product deleted successfully')
      end
    end
  end
end
