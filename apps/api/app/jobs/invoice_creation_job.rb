# frozen_string_literal: true

class InvoiceCreationJob < ApplicationJob
  queue_as :default

  def perform(payment)
    Invoices::Creation.call(payment)
  end
end
