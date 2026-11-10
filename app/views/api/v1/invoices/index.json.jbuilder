# frozen_string_literal: true

json.invoices @invoices, partial: 'api/v1/invoices/invoice', as: :invoice
