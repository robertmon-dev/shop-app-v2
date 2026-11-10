# frozen_string_literal: true

class CreateSecondFactorCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :second_factor_codes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :second_factor_codes, :code, unique: true
  end
end
