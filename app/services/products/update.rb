# frozen_string_literal: true

module Services
  class ProductUpdateService
    extend Concerns::Handlers
    extend Concerns::ResultHelpers

    def self.call(product, params)
      with_error_handling do
        ActiveRecord::Base.transaction do
          product.update!(params.except(:product_photo_ids))

          ProductManagementService.assign_photos(product: product, photo_ids: params[:product_photo_ids])

          ProductCachingService.invalidate_for_product(product)
        end
        success_result(data: { product: product }, message: 'Product updated successfully')
      end
    end
  end
end
