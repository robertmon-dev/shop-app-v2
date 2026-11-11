class CreateRefunds < ActiveRecord::Migration[8.0]
  def change
    create_table :refunds do |t|
      t.text :description, null: false
      t.text :reason, null: false
      t.integer :status, null: false, default: 0
      t.integer :payment_status, null: false, default: 0
      t.datetime :refund_date, null: true
      t.references :user, null: true, foreign_key: true
      t.references :order, null: true, foreign_key: true
      t.references :payment, null: true, foreign_key: true
      t.timestamps
    end
  end
end
