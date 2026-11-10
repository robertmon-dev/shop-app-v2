# frozen_string_literal: true

module Services
  class RefundManagementService
    extend Concerns::Handlers
    extend Concerns::ResultHelpers

    def initialize(refund)
      @refund = refund
    end

    def cancel
      return wrong_refund_status_result unless @refund.status_pending? || @refund.status_processing?

      with_error_handling do
        if @refund.update(status: :cancelled)
          success_result(data: { refund: @refund }, message: 'Refund cancelled successfully')
        else
          unprocessable_content_result(errors: @refund.errors.full_messages,
                                       messages: 'Refund cancellation failed due to validation errors')
        end
      end
    end

    def complete
      return wrong_refund_status_result if @refund.status_rejected? || @refund.status_pending?

      with_error_handling do
        ActiveRecord::Base.transaction do
          @refund.update!(status: :refunded)
        end
        success_result(data: { refund: @refund, message: 'Refund completed successfully' })
      end
    end

    def mark_refund_status(status)
      mark_status(:status, status, Refund.statuses)
    end

    def mark_payment_status(status)
      mark_status(:payment_status, status, Refund.payment_statuses)
    end

    def mark_status(attribute, status, valid_statuses)
      with_error_handling do
        status_key = status.to_s
        unless valid_statuses.key?(status_key)
          return unprocessable_content_result(errors: ["'#{status_key}' is not a valid #{attribute}"])
        end

        if @refund.update(attribute => status_key)
          success_result(data: { refund: @refund },
                         message: "Refund #{attribute} successfully updated to '#{status_key}'.")
        else
          unprocessable_content_result(errors: @refund.errors.full_messages,
                                       message: "Failed to update refund #{attribute}")
        end
      end
    end
  end
end
