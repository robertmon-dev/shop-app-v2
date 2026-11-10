# frozen_string_literal: true

class Payment < ApplicationRecord
  belongs_to :order
  has_one :invoice, dependent: :nullify

  enum :status, { unpaid: 0, paid: 1, failed: 2, refunded: 3 }, prefix: true, default: :unpaid

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :payment_method, presence: true
  validates :stripe_payment_intent_id, presence: true, uniqueness: true
  validates :stripe_charge_id, uniqueness: true, allow_nil: true
  validates :currency, presence: true

  before_validation :set_default_currency, on: :create

  def self.create_from_payment_intent(payment_intent)
    order = Order.find_by!(stripe_payment_intent_id: payment_intent.id)
    charge = payment_intent.latest_charge

    create!(
      order: order,
      amount: payment_intent.amount_received / 100.0,
      status: :paid,
      payment_method: "#{charge.payment_method_details.type} (#{charge.payment_method_details.card.brand})",
      stripe_payment_intent_id: payment_intent.id,
      stripe_charge_id: charge.id,
      currency: payment_intent.currency.upcase
    )
  end

  def mark_as_paid!
    update!(status: :paid)
  end

  def mark_as_failed!(message = nil)
    update!(status: :failed, error_message: message)
  end

  def mark_as_refunded!(message = nil)
    update!(status: :refunded, error_message: message)
  end

  private

  def set_default_currency
    self.currency ||= 'pln'
  end
end
