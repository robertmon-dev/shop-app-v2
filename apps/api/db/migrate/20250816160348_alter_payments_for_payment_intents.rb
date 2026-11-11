# frozen_string_literal: true

class AlterPaymentsForPaymentIntents < ActiveRecord::Migration[8.0]
  def change
    remove_column :payments, :transaction_id, :string
    rename_column :payments, :stripe_charge_id, :stripe_payment_intent_id

    add_column :payments, :stripe_charge_id, :string

    add_index :payments, :stripe_payment_intent_id, unique: true
    add_index :payments, :stripe_charge_id, unique: true
  end
end
