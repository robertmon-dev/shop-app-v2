class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.references :order, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.integer :status, null: false, default: 0
      t.string :payment_method, null: false
      t.string :transaction_id
      t.string :stripe_charge_id
      t.string :currency, null: false
      t.text :error_message
      t.timestamps

      t.index :transaction_id, unique: true
    end
  end
end
