# frozen_string_literal: true

class InvoiceObserver < ApplicationObserver
  observe :invoice

  def after_create(invoice)
    Rails.logger.info "InvoiceObserver: Invoice created (ID: #{invoice.id}, Number: #{invoice.invoice_number})"
    InvoicePDFCreationJob.perform_later(invoice)
  end
end
