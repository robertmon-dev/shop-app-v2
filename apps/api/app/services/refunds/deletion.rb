# frozen_string_literal: true

module Refunds
  class Deletion < ApplicationService
    def initialize(refund)
      @refund = refund
    end

    def call
      return missing_result('Refund') unless @refund

      with_error_not_destroyed_handling do
        @refund.destroy!
        destroy_success_result(message: 'Refund deleted successfully')
      end
    end
  end
end
