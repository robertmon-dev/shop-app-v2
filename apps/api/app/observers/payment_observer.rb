# frozen_string_literal: true

class PaymentObserver < ApplicationObserver
  observe :payment

  def after_commit(payment)
    return unless payment.saved_change_to_status? && payment.status_paid?

    Rails.logger.info "Payment ##{payment.id} is paid, enqueueing invoice creation"
    InvoiceCreationJob.perform_later(payment)
  end
end
