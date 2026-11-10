# frozen_string_literal: true

class CreateItems < ActiveRecord::Migration[8.0]
  def change
    create_table :items do |t|
      t.references :order, null: true, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.references :product, type: :uuid, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.decimal :price_at_purchase, precision: 10, scale: 2, null: false
      t.timestamps
    end
  end
end
