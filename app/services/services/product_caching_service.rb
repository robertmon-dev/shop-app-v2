# frozen_string_literal: true

module Services
  class ProductCachingService
    extend Concerns::Handlers
    extend Concerns::ResultHelpers

    INDEX_KEY_PREFIX = 'products:page'
    SHOW_KEY_PREFIX = 'product'
    VERSION_KEY = 'products:version'
    CACHE_EXPIRATION = 1.hour

    def self.fetch_all(page = 1)
      perform_caching_flow(
        cache_key_proc: -> { index_cache_key(page) },
        db_query_proc: -> { db_query_for_all(page) },
        result_key: :products,
        success_message: 'Products have been found',
        failure_message: 'No products found',
        errors: ['Products not found']
      )
    end

    def self.fetch_one(id)
      perform_caching_flow(
        cache_key_proc: -> { show_cache_key(id) },
        db_query_proc: -> { db_query_for_one(id) },
        result_key: :product,
        success_message: 'Product has been found',
        failure_message: 'Product not found',
        errors: ['Product not found']
      )
    end

    def self.perform_caching_flow(cache_key_proc:, db_query_proc:, result_key:, success_message:, errors:,
                                  failure_message:)
      data = with_redis_fallback(db_query_proc) do
        Rails.cache.fetch(cache_key_proc.call, expires_in: CACHE_EXPIRATION) do
          db_query_proc.call
        end
      end

      if data.present?
        success_result(data: { result_key => data }, message: success_message)
      else
        not_found_result(errors: errors, message: failure_message)
      end
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
