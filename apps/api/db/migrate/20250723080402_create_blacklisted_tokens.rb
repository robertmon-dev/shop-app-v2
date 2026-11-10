# frozen_string_literal: true

class CreateBlacklistedTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :blacklisted_tokens do |t|
      t.string :token, null: false
      t.references :owner, null: false, foreign_key: { to_table: :users }, type: :bigint
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :blacklisted_tokens, :token, unique: true
    add_index :blacklisted_tokens, :expires_at
  end
end
