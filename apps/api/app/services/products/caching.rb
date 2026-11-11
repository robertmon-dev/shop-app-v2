# frozen_string_literal: true

module Products
  class Caching < ApplicationService
    INDEX_KEY_PREFIX = 'products:page'
    SHOW_KEY_PREFIX = 'product'
    VERSION_KEY = 'products:version'
    CACHE_EXPIRATION = 1.hour

    ALL_MESSAGES = { success: 'Products have been found', failure: 'No products found',
                     errors: ['Products not found'] }.freeze
    ONE_MESSAGES = { success: 'Product has been found', failure: 'Product not found',
                     errors: ['Product not found'] }.freeze

    def self.fetch_all(page = 1)
      perform_caching_flow(cache_key_proc: -> { index_cache_key(page) }, result_key: :products,
                           messages: ALL_MESSAGES) { db_query_for_all(page) }
    end

    def self.fetch_one(id)
      perform_caching_flow(cache_key_proc: -> { show_cache_key(id) }, result_key: :product,
                           messages: ONE_MESSAGES) { db_query_for_one(id) }
    end

    def self.perform_caching_flow(cache_key_proc:, result_key:, messages:, &db_query)
      data = with_redis_fallback(db_query) do
        Rails.cache.fetch(cache_key_proc.call, expires_in: CACHE_EXPIRATION, &db_query)
      end
      return not_found_result(errors: messages[:errors], message: messages[:failure]) if data.blank?

      success_result(data: { result_key => data }, message: messages[:success])
    end

    def self.invalidate_for_product(product)
      with_redis_fallback(-> {}) do
        Rails.cache.delete(show_cache_key(product.id))
        increment_version
      end
    end

    private

    def self.base_query
      Product.with_details.includes(:product_photos, :product_likes, :comments)
    end

    def self.db_query_for_all(page)
      base_query.page(page).per(25).to_a
    end

    def self.db_query_for_one(id)
      base_query.find_by(id: id)
    end

    def self.index_cache_key(page)
      version = Rails.cache.fetch(VERSION_KEY) { 1 }
      "#{INDEX_KEY_PREFIX}:#{page}:v#{version}"
    end

    def self.show_cache_key(id)
      "#{SHOW_KEY_PREFIX}:#{id}"
    end

    def self.increment_version
      Rails.cache.increment(VERSION_KEY)
    end

    private_class_method :index_cache_key, :show_cache_key, :increment_version, :index_cache_key, :db_query_for_one,
                         :base_query, :db_query_for_all
  end
end
