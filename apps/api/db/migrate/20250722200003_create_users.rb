# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :mail, null: false
      t.string :password_digest, null: false
      t.string :phone, null: true
      t.integer :role, null: false, default: 0
      t.boolean :active, null: false, default: false
      t.boolean :verified, null: false, default: false
      t.boolean :two_factor_enabled, null: false, default: false
      t.timestamps
    end

    add_index :users, :mail, unique: true
    add_index :users, :phone, unique: true, where: 'phone IS NOT NULL'
  end
end
