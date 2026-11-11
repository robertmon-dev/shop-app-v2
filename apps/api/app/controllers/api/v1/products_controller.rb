# frozen_string_literal: true

module Api
  module V1
    class ProductsController < Api::ApplicationController
      skip_before_action :authenticate_user!, only: %i[index show]
      load_and_authorize_resource except: %i[index show available_categories create_category
                                             update_category destroy_category]
      before_action :authorize_category_management!, only: %i[create_category update_category destroy_category]
      before_action :set_category, only: %i[update_category destroy_category]

      def index = respond_with_view(:index, products: paginated_products)
      def show = respond_with(Products::Caching.fetch_one(params[:id]))
      def create = respond_with(Products::Creation.call(product_params))
      def update = respond_with(Products::Update.call(@product, product_params))
      def destroy = respond_with_destroy(Products::Deletion.call(@product))
      def like = respond_with(product_interaction_service.like(@product))
      def rate = respond_with(product_interaction_service.rate(@product, *rate_args))
      def comment = respond_with(product_interaction_service.add_comment(@product, *comment_args))
      def create_photo = respond_with(Products::PhotoCreation.call(**photo_args), :photo)

      def available_categories = respond_with_view(:categories, categories: Category.order(:name))
      def create_category = respond_with(category_service.create(category_params), :category)
      def update_category = respond_with(category_service.update(@category, category_params), :category)
      def destroy_category = respond_with_destroy(category_service.destroy(@category))

      private

      def authorize_category_management! = authorize!(:manage, Category)

      def category_service = Categories::Management

      def paginated_products
        Product.with_details.order(created_at: :desc).page(params[:page]).per(25)
      end

      def product_interaction_service
        @product_interaction_service ||= Products::Interaction.new(current_user)
      end

      def photo_args = { image: params[:image], product: @product }
      def rate_args = [rate_params[:rating], rate_params[:comment]]
      def comment_args = [comment_params[:content], comment_params[:parent_id]]

      def set_category
        @category = Category.find_by(id: params[:category_id] || params[:id])
      end

      def category_params
        params.require(:category).permit(:name, :parent_id, product_ids: [])
      end

      def rate_params
        params.require(:product_rating).permit(:rating, :comment)
      end

      def comment_params
        params.require(:product_comment).permit(:content, :parent_id)
      end

      def product_params
        params.require(:product).permit(
          :name, :price, :description, :vat_rate, :weight_kg, :height_cm, :width_cm, :length_cm,
          product_photos_attributes: %i[id _destroy],
          product_photo_ids: []
        )
      end
    end
  end
end
