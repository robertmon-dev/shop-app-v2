# frozen_string_literal: true

module Carts
  module SummaryCache
    TTL = 1.hour

    module_function

    def fetch(user, &) = Rails.cache.fetch(key(user.id, user.created_at), expires_in: TTL, &)

    def expire(user_id)
      created_at = User.where(id: user_id).pick(:created_at)
      Rails.cache.delete(key(user_id, created_at)) if created_at
    end

    def expire_for_product(product_id)
      Item.where(product_id: product_id, order_id: nil).where.not(user_id: nil).distinct.pluck(:user_id)
          .each { |user_id| expire(user_id) }
    end

    def key(user_id, created_at) = "carts/#{user_id}/#{created_at.utc.to_fs(:usec)}/summary"
  end
end
