# frozen_string_literal: true

class WidenInvoiceMoneyColumns < ActiveRecord::Migration[8.0]
  def up
    change_column :invoices, :tax_value, :decimal, precision: 12, scale: 2, null: false
    change_column :invoices, :total_gross, :decimal, precision: 12, scale: 2, null: false
    change_column :invoices, :total_net, :decimal, precision: 12, scale: 2, null: false
    change_column :invoices, :buyer_tax_id, :string, null: true
  end

  def down
    change_column :invoices, :tax_value, :decimal, precision: 5, scale: 2, null: false
    change_column :invoices, :total_gross, :decimal, precision: 5, scale: 2, null: false
    change_column :invoices, :total_net, :decimal, precision: 5, scale: 2, null: false
    change_column :invoices, :buyer_tax_id, :string, null: false
  end
end
