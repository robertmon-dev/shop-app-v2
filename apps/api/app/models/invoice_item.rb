# frozen_string_literal: true

class InvoiceItem < ApplicationRecord
  belongs_to :invoice
  belongs_to :product

  validates :name, :unit_of_measure, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :net_price, :vat_rate, :total_net_price, :total_vat_price, :total_gross_price,
            presence: true, numericality: { greater_than_or_equal_to: 0 }
end
