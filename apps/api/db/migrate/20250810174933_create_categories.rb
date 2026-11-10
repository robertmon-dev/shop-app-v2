# frozen_string_literal: true

class CreateCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :categories, id: :uuid do |t|
      t.string :name, null: false
      t.references :parent, foreign_key: { to_table: :categories }, type: :uuid

      t.timestamps
    end
    add_index :categories, :name, unique: true
  end
end
