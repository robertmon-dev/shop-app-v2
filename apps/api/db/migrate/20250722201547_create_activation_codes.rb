# frozen_string_literal: true

class CreateActivationCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :activation_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :activation_codes, :code, unique: true
  end
end
