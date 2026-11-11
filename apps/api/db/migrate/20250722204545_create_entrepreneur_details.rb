# frozen_string_literal: true

class CreateEntrepreneurDetails < ActiveRecord::Migration[8.0]
  def change
    create_table :entrepreneur_details do |t|
      t.references :user_detail, null: false, foreign_key: true, index: { unique: true }
      t.string :business_name
      t.string :nip
      t.string :krs
      t.text :description
      t.text :offer
      t.float :income
      t.float :costs
      t.float :funding_capital
      t.string :industry
      t.jsonb :management_council_members
      t.jsonb :decision_makers
      t.string :business_phone_number
      t.string :business_mail
      t.string :website_address
      t.timestamps
    end

    add_index :entrepreneur_details, :nip, unique: true
    add_index :entrepreneur_details, :krs, unique: true
  end
end
