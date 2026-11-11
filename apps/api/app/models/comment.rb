# frozen_string_literal: true

class Comment < ApplicationRecord
  belongs_to :product, foreign_key: 'product_id', inverse_of: :comments
  belongs_to :user, inverse_of: :comments

  belongs_to :parent, class_name: 'Comment', optional: true, counter_cache: :replies_count, inverse_of: :replies
  has_many :replies, class_name: 'Comment', foreign_key: 'parent_id', dependent: :destroy, inverse_of: :parent

  validates :content, presence: true
  validates :replies_count, numericality: { greater_than_or_equal_to: 0 }

  scope :top_level, -> { where(parent_id: nil) }
  scope :recent, -> { order(created_at: :desc) }

  def top_level?
    parent_id.nil?
  end
end
