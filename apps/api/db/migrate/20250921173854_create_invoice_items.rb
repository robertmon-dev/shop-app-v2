class CreateInvoiceItems < ActiveRecord::Migration[8.0]
  def change
    create_table :invoice_items do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :product, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :quantity, null: false
      t.string :unit_of_measure, null: false, default: 'szt.'
      t.decimal :net_price, precision: 10, scale: 2, null: false
      t.decimal :vat_rate, precision: 5, scale: 2, null: false
      t.decimal :total_net_price, precision: 10, scale: 2, null: false
      t.decimal :total_vat_price, precision: 10, scale: 2, null: false
      t.decimal :total_gross_price, precision: 10, scale: 2, null: false
      t.timestamps
    end
  end
end
