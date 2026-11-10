# frozen_string_literal: true

class CreateBans < ActiveRecord::Migration[8.0]
  def change
    create_table :bans do |t|
      t.text :reason
      t.datetime :expires_at

      t.references :user, null: false, foreign_key: { to_table: :users }
      t.references :owner, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
