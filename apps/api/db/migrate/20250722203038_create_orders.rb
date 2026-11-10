# frozen_string_literal: true

class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.decimal :total_amount, precision: 10, scale: 2, default: 0.0
      t.integer :status, default: 0
      t.integer :payment_status, default: 0
      t.datetime :order_date, null: false
      t.integer :package_carrier, null: true
      t.text :transaction_id, null: true
      t.string :package_type
      t.text :notes
      t.integer :shipping_service_id
      t.timestamps
    end
  end
end
