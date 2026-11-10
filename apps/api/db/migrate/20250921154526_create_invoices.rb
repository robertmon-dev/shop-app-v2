class CreateInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :invoices do |t|
      t.references :user, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.references :payment, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true

      t.text :url, null: true
      t.text :thumbnail_url, null: true

      t.string :full_address, null: false
      t.string :buyer_name, null: false
      t.string :buyer_tax_id, null: false

      t.datetime :sale_date, null: false
      t.datetime :due_date, null: false

      t.string :invoice_number, null: false
      t.index :invoice_number, unique: true

      t.decimal :tax_value, null: false, precision: 5, scale: 2
      t.decimal :total_gross, null: false, precision: 5, scale: 2
      t.decimal :total_net, null: false, precision: 5, scale: 2

      t.timestamps
    end
  end
end
