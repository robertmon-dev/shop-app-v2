# frozen_string_literal: true

class AddStripePaymentIntentIdToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :stripe_payment_intent_id, :string
    add_index :orders, :stripe_payment_intent_id, unique: true
  end
end
