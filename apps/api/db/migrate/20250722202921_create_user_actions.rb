# frozen_string_literal: true

class CreateUserActions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_actions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action_type, null: false
      t.string :action, null: false
      t.text :details
      t.timestamps
    end
  end
end
