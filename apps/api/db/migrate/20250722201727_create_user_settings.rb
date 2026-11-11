# frozen_string_literal: true

class CreateUserSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :user_settings do |t|
      t.boolean :two_factor, null: false, default: false
      t.boolean :night_mode, null: false, default: false
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.timestamps
    end
  end
end
