# frozen_string_literal: true

class Item < ApplicationRecord
  belongs_to :order, optional: true
  belongs_to :user, optional: true
  belongs_to :product

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price_at_purchase, presence: true, numericality: { greater_than_or_equal_to: 0 }

  validate :must_belong_to_user_or_order

  after_create :recalculate_order_total
  after_update :recalculate_order_total, if: :pricing_changed?
  after_destroy :recalculate_order_total
  after_commit :expire_cart_summary

  def subtotal
    quantity * price_at_purchase
  end

  private

  def expire_cart_summary
    [user_id, user_id_before_last_save].compact.uniq.each { |id| Carts::SummaryCache.expire(id) }
  end

  def pricing_changed?
    saved_change_to_quantity? || saved_change_to_price_at_purchase?
  end

  def must_belong_to_user_or_order
    errors.add(:base, 'Item must belong to a user (for cart) or an order') unless user_id.present? || order_id.present?
    return unless user_id.present? && order_id.present?

    errors.add(:base, 'Item cannot belong to both a user (cart) and an order simultaneously')
  end

  def recalculate_order_total
    order&.recalculate_total!
  end
end
