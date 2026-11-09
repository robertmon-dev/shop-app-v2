# frozen_string_literal: true

class Invoice < ApplicationRecord
  belongs_to :user
  belongs_to :order
  belongs_to :payment
  belongs_to :location

  has_many :invoice_items, dependent: :destroy
  has_many :products, through: :invoice_items

  validates :invoice_number, presence: true, uniqueness: true
  validates :buyer_name, :full_address, presence: true
  validates :sale_date, :due_date, presence: true
  validates :tax_value, :total_gross, :total_net,
            presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :recent, -> { order(created_at: :desc) }

  def accessible_by?(user)
    self.user == user || user.admin?
  end

  def recalculate_totals!
    self.total_net = invoice_items.sum(&:total_net_price)
    self.tax_value = invoice_items.sum(&:total_vat_price)
    self.total_gross = invoice_items.sum(&:total_gross_price)
  end
end
