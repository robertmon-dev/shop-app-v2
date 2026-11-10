# frozen_string_literal: true

class PaymentObserver < ApplicationObserver
  observe :payment

  def after_update(payment)
    Rails.logger.info "Payment status has been updated to: #{payment.status}"
    return unless payment.status_paid?

    InvoiceCreationJob.perform_later(payment)
  end
end
