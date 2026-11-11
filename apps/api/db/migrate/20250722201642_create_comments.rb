# frozen_string_literal: true

class CreateComments < ActiveRecord::Migration[7.0]
  def change
    create_table :comments do |t|
      t.references :product, type: :uuid, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content, null: false
      t.references :parent, foreign_key: { to_table: :comments }, index: true
      t.integer :replies_count, default: 0, null: false
      t.timestamps
    end
  end
end
