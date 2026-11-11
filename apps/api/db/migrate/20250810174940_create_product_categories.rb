# frozen_string_literal: true

class CreateProductCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :product_categories, id: false do |t|
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.references :category, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end

    add_index :product_categories, %i[product_id category_id], unique: true
  end
end
