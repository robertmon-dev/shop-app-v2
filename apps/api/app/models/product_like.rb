# frozen_string_literal: true

class ProductLike < ApplicationRecord
  belongs_to :user
  belongs_to :product

  validates :user_id, uniqueness: { scope: :product_id, message: 'has already liked this product' }
end
