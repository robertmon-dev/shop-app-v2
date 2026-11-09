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
      return render_errors unless @success

      assign_resources
      render view, status: @status, locals: locals
    end

    def respond_with_view(view, status: :ok, locals: {}, **assigns)
      @status = status
      @errors = []
      @message = nil
      assign(assigns)
      render view, status: status, locals: locals
    end

    def respond_with_message(result)
      bind_data(result)
      return render_errors unless @success

      render json: { message: @message }, status: @status
    end

    def respond_with_destroy(result)
      bind_data(result)
      return render_errors unless @success

      head :no_content
    end

    def respond_in_view(result, view, locals: {})
      bind_data(result)
      assign_resources
      render view, status: @status, locals: locals
    end

    def render_errors
      render json: { errors: @errors }, status: @status
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
