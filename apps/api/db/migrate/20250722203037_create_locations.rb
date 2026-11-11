# frozen_string_literal: true

class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations do |t|
      t.references :user_detail, null: true, foreign_key: true
      t.string :country, null: false
      t.string :province, null: false
      t.string :city, null: false
      t.string :postal_code, null: false
      t.string :street
      t.integer :building_number
      t.integer :apartment_number
      t.timestamps
    end
  end
end
