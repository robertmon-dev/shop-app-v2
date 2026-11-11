# frozen_string_literal: true

json.id invoice.id
json.invoice_number invoice.invoice_number
json.order_id invoice.order_id
json.payment_id invoice.payment_id
json.buyer_name invoice.buyer_name
json.buyer_tax_id invoice.buyer_tax_id
json.full_address invoice.full_address
json.sale_date invoice.sale_date
json.due_date invoice.due_date
json.total_net invoice.total_net
json.tax_value invoice.tax_value
json.total_gross invoice.total_gross
json.url invoice.url
json.created_at invoice.created_at

json.items invoice.invoice_items do |item|
  json.id item.id
  json.name item.name
  json.quantity item.quantity
  json.unit_of_measure item.unit_of_measure
  json.net_price item.net_price
  json.vat_rate item.vat_rate
  json.total_net_price item.total_net_price
  json.total_vat_price item.total_vat_price
  json.total_gross_price item.total_gross_price
end
