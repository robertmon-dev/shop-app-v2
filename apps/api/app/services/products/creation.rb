# frozen_string_literal: true

module Products
  class Creation < ApplicationService
    def initialize(params)
      @params = params
    end

    def call
      with_error_handling do
        product = Product.new(@params.except(:product_photo_ids))
        ActiveRecord::Base.transaction do
          product.save!
          PhotoAssignment.assign_photos(product: product, photo_ids: @params[:product_photo_ids])
          Caching.invalidate_for_product(product)
        end
        success_result(data: { product: product }, message: 'Product created successfully', status: :created)
      end
    end
  end
end
