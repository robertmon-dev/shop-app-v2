# frozen_string_literal: true

class InvoicePDFCreationJob < ApplicationJob
  queue_as :default

  def perform(invoice)
    render_result = Invoices::PDFGeneration.call(invoice)
    return log_failure(invoice, render_result) unless render_result.success?

    upload_result = Storage::S3Upload.call(
      data: render_result.data[:pdf],
      filename: render_result.data[:filename],
      content_type: 'application/pdf'
    )
    return log_failure(invoice, upload_result) unless upload_result.success?

    invoice.update!(url: upload_result.data[:url])
  end

  private

  def log_failure(invoice, result)
    Rails.logger.error "InvoicePDFCreationJob failed for invoice #{invoice.id}: #{result.errors.join(', ')}"
  end
end
