# frozen_string_literal: true

module Services
  class InvoiceCreationService
    include Concerns::Handlers
    include Concerns::ResultHelpers

    PAYMENT_TERM_DAYS = 14
    NUMBER_PREFIX = 'FV'

    def self.call(payment) = new(payment).call

    def initialize(payment)
      @payment = payment
    end

    def call
      return already_invoiced_result if @payment.invoice

      with_error_handling do
        invoice = nil

        ActiveRecord::Base.transaction do
          order = find_order_with_details
          invoice = build_invoice(order)
          build_invoice_items(invoice, order)
          invoice.recalculate_totals!
          invoice.save!
        end

        success_result(data: { invoice: invoice }, message: 'Invoice created successfully', status: :created)
      end
    end

    private

    def find_order_with_details
      Order.includes({ user: { user_detail: %i[entrepreneur_detail locations] } }, { items: :product }, :location)
           .find(@payment.order_id)
    end

    def build_invoice(order)
      buyer = order.user

      Invoice.new(
        user: buyer,
        order: order,
        payment: @payment,
        location: order.location,
        full_address: order.location.full_address,
        invoice_number: next_invoice_number,
        buyer_name: buyer_name(buyer),
        buyer_tax_id: buyer_tax_id(buyer),
        sale_date: @payment.created_at,
        due_date: @payment.created_at + PAYMENT_TERM_DAYS.days
      )
    end

    def build_invoice_items(invoice, order)
      order.items.each { |item| build_invoice_item(invoice, item) }
    end

    def build_invoice_item(invoice, item)
      product = item.product
      net = item.quantity * item.price_at_purchase
      vat = (net * product.vat_rate).round(2)

      invoice.invoice_items.build(
        product: product,
        name: product.name,
        quantity: item.quantity,
        unit_of_measure: product.unit_of_measure,
        net_price: item.price_at_purchase,
        vat_rate: product.vat_rate,
        total_net_price: net,
        total_vat_price: vat,
        total_gross_price: net + vat
      )
    end

    def buyer_name(buyer)
      business_name = buyer.user_detail&.entrepreneur_detail&.business_name
      business_name.presence || buyer.user_detail&.full_name.presence || buyer.mail
    end

    def buyer_tax_id(buyer)
      buyer.user_detail&.entrepreneur_detail&.nip
    end

    def next_invoice_number
      prefix = "#{NUMBER_PREFIX}/#{Date.current.strftime('%Y/%m')}"
      last_number = Invoice.where('invoice_number LIKE ?', "#{prefix}/%")
                           .order(Arel.sql('LENGTH(invoice_number) DESC, invoice_number DESC'))
                           .pick(:invoice_number)

      "#{prefix}/#{last_number ? last_number.split('/').last.to_i + 1 : 1}"
    end

    def already_invoiced_result
      conflict_result(errors: ['Payment already has an invoice.'],
                      message: "Payment ##{@payment.id} already has an invoice.")
    end
  end
end
