# frozen_string_literal: true

json.invoice do
  json.partial! 'api/v1/invoices/invoice', invoice: @invoice
end
