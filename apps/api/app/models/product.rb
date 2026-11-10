# frozen_string_literal: true

class Product < ApplicationRecord
  has_many :product_photos, dependent: :destroy
  has_many :comments, dependent: :destroy, inverse_of: :product
  has_many :product_likes, dependent: :destroy
  has_many :product_rates, dependent: :destroy

  has_many :product_categories, dependent: :destroy
  has_many :categories, through: :product_categories

  has_many :invoice_items
  accepts_nested_attributes_for :product_photos, allow_destroy: true
  validates :name, presence: true
  validates :price, :vat_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :weight_kg, :height_cm, :width_cm, :length_cm,
            presence: true, numericality: { greater_than: 0 }

  scope :with_details, -> { includes(:product_photos, :comments, :product_likes, :product_rates, :categories) }
end
