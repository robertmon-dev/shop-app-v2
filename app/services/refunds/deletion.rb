# frozen_string_literal: true

module Services
  class RefundDeletionService
    extend Concerns::Handlers
    extend Concerns::ResultHelpers

    def self.call(refund)
      with_error_not_destroyed_handling do
        return not_found_result(errors: ['refund not found'], message: 'refund not found') unless refund

        ActiveRecord::Base.transaction do
          refund.destroy!
        end

        success_result(status: :no_content, message: 'Refund deleted successfully')
      end
    end
  end
end
