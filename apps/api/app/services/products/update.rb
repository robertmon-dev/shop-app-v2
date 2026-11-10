# frozen_string_literal: true

module Products
  class Update < ApplicationService
    def initialize(product, params)
      @product = product
      @params = params
    end

    def call
      with_error_handling do
        ActiveRecord::Base.transaction do
          @product.update!(@params.except(:product_photo_ids))
          PhotoAssignment.assign_photos(product: @product, photo_ids: @params[:product_photo_ids])
          Caching.invalidate_for_product(@product)
        end
        success_result(data: { product: @product }, message: 'Product updated successfully')
      end
    end
  end
end
