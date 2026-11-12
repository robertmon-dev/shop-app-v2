# frozen_string_literal: true

class AddStockQuantityToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :stock_quantity, :integer
    add_check_constraint :products, 'stock_quantity IS NULL OR stock_quantity >= 0',
                         name: 'products_stock_quantity_non_negative'
  end
end
