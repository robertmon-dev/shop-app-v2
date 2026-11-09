# frozen_string_literal: true

class Refund < ApplicationRecord
  belongs_to :order
  belongs_to :user
  belongs_to :payment, optional: true

  validates :reason, presence: true
  validates :description, presence: true

  enum :status, { pending: 0, processing: 1, cancelled: 2, refunded: 4, rejected: 5 }, prefix: true, default: :pending
  enum :payment_status, { unpaid: 0, paid: 1, failed: 2, refunded: 3 }, prefix: true, default: :unpaid

  scope :recent, -> { order(refund_date: :desc).limit(10) }
  scope :cancelled, -> { where(status: :cancelled) }
  scope :refunded, -> { where(status: :refunded) }
  scope :processing, -> { where(status: :processing) }
  scope :rejected, -> { where(status: :rejected) }
end
