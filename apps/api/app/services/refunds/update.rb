# frozen_string_literal: true

module Refunds
  class Update < ApplicationService
    TRANSITIONS = {
      'pending' => %w[processing rejected],
      'processing' => %w[rejected]
    }.freeze

    def initialize(refund, params)
      @refund = refund
      @params = params
    end

    def call
      return missing_result('Refund') unless @refund

      rejected = forbidden_transition
      return rejected if rejected

      with_error_handling do
        @refund.update!(@params)
        success_result(data: { refund: @refund }, message: 'Refund updated successfully')
      end
    end

    private

    def target_status = @params[:status].presence&.to_s

    def forbidden_transition
      return if target_status.nil? || target_status == @refund.status
      return if TRANSITIONS.fetch(@refund.status, []).include?(target_status)

      message = "Cannot change refund status from #{@refund.status} to #{target_status}."
      unprocessable_content_with_errors_result(errors: [message], message: message)
    end
  end
end
