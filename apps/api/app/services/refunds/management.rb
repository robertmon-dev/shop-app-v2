# frozen_string_literal: true

module Refunds
  class Management < ApplicationService
    def initialize(refund)
      @refund = refund
    end

    def cancel
      return wrong_refund_status_result(refund: @refund) unless @refund.status_pending? || @refund.status_processing?

      with_error_handling do
        @refund.update!(status: :cancelled)
        success_result(data: { refund: @refund }, message: 'Refund cancelled successfully')
      end
    end

    def complete
      return wrong_refund_status_result(refund: @refund) if @refund.status_rejected? || @refund.status_pending?

      with_error_handling do
        @refund.update!(status: :refunded)
        success_result(data: { refund: @refund }, message: 'Refund completed successfully')
      end
    end

    def mark_refund_status(status)
      mark_status(:status, status, Refund.statuses)
    end

    def mark_payment_status(status)
      mark_status(:payment_status, status, Refund.payment_statuses)
    end

    private

    def mark_status(attribute, status, valid_statuses)
      status_key = status.to_s
      return invalid_status_result(attribute, status_key) unless valid_statuses.key?(status_key)

      with_error_handling do
        @refund.update!(attribute => status_key)
        success_result(data: { refund: @refund },
                       message: "Refund #{attribute} successfully updated to '#{status_key}'.")
      end
    end

    def invalid_status_result(attribute, status_key)
      invalid_result('Invalid status provided.', errors: ["'#{status_key}' is not a valid #{attribute}"])
    end
  end
end
