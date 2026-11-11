# frozen_string_literal: true

module Api
  module Responding
    extend ActiveSupport::Concern

    ASSIGNABLE_KEYS = %i[
      user users user_detail entrepreneur_detail location product products product_photo product_photos
      order orders payment payments refund refunds category categories item items
      invoice invoices invoice_items token
    ].freeze

    private

    def respond_with(result, view = :show, locals: {})
      bind_data(result)
      return render_result_failure unless @success

      assign_resources
      render view, status: @status, locals: locals
    end

    def respond_with_message(result)
      bind_data(result)
      return render_result_failure unless @success

      render 'shared/empty', status: @status
    end

    def respond_with_destroy(result)
      bind_data(result)
      return render_result_failure unless @success

      head :no_content
    end

    def respond_with_view(view, status: :ok, message: nil, locals: {}, **assigns)
      @status = status
      @success = true
      @errors = []
      @message = message
      assign(assigns)
      @pagination = assigns.values.find { |value| value.respond_to?(:current_page) }
      render view, status: status, locals: locals
    end

    def render_failure(message:, status:, errors: [message], data: nil)
      body = { success: false, message: message, errors: Array(errors) }
      body[:data] = data if data.present?
      render json: body, status: status
    end

    def render_result_failure
      render_failure(message: @message, errors: @errors, status: @status)
    end

    def assign_resources
      return unless @data.is_a?(Hash)

      assign(@data.select { |key, _| ASSIGNABLE_KEYS.include?(key.to_sym) })
    end

    def assign(assigns)
      assigns.each { |name, value| instance_variable_set(:"@#{name}", value) }
    end
  end
end
