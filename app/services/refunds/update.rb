# frozen_string_literal: true

module Refunds
  class Update < ApplicationService
    def initialize(refund, params)
      @refund = refund
      @params = params
    end

    def call
      return missing_result('Refund') unless @refund

      with_error_handling do
        @refund.update!(@params)
        success_result(data: { refund: @refund }, message: 'Refund updated successfully')
      end
    end
  end
end
