# frozen_string_literal: true

module Api
  module V1
    class InvoicesController < Api::ApplicationController
      load_and_authorize_resource except: [:me]

      def index = respond_with_view(:index, invoices: accessible_invoices)
      def me = respond_with_view(:index, invoices: own_invoices)
      def show = respond_with_view(:show)
      def download = respond_with(Services::InvoicePDFGenerationService.call(@invoice), :download)

      private

      def accessible_invoices
        Invoice.accessible_by(current_ability).includes(:order, :invoice_items).recent.page(params[:page]).per(25)
      end

      def own_invoices
        current_user.invoices.includes(:order, :invoice_items).recent.page(params[:page]).per(25)
      end
    end
  end
end
