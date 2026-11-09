# frozen_string_literal: true

json.invoices @invoices do |invoice|
  json.partial! 'api/v1/invoices/invoice', invoice: invoice
end

json.meta do
  json.current_page @invoices.current_page
  json.next_page @invoices.next_page
  json.prev_page @invoices.prev_page
  json.total_pages @invoices.total_pages
  json.total_count @invoices.total_count
end
