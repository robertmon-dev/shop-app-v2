# frozen_string_literal: true

class ProductRate < ApplicationRecord
  belongs_to :user
  belongs_to :product

  validates :rating, presence: true, numericality: { only_integer: true, in: 1..5 }
  validates :user_id, uniqueness: { scope: :product_id, message: 'has already rated this product' }

  validates :comment, length: { maximum: 1000 }, allow_nil: true
end
