# frozen_string_literal: true

require 'prawn'
require 'prawn/table'

module Services
  class InvoicePDFGenerationService
    include Concerns::Handlers
    include Concerns::ResultHelpers

    HEADERS = ['Lp.', 'Usługa/Produkt', 'Ilość', 'J.m.', 'Cena jedn. netto', 'Wartość netto', 'VAT',
               'Wartość brutto'].freeze

    FONT_CANDIDATES = [
      'app/assets/fonts/DejaVuSans.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      '/usr/share/fonts/TTF/DejaVuSans.ttf',
      '/usr/share/fonts/dejavu/DejaVuSans.ttf'
    ].freeze

    def self.call(invoice) = new(invoice).call

    def initialize(invoice)
      @invoice = invoice
    end

    def call
      with_error_handling do
        success_result(data: { pdf: render, filename: filename },
                       message: "Invoice #{@invoice.invoice_number} rendered successfully")
      end
    end

    def render
      document = Prawn::Document.new(page_size: 'A4', margin: 36)
      apply_font(document)
      add_header(document)
      add_parties(document)
      add_items_table(document)
      add_totals(document)

      document.render
    end

    def filename = "#{@invoice.invoice_number.tr('/', '-')}.pdf"

    private

    def font_path
      return @font_path if defined?(@font_path)

      candidates = [ENV.fetch('INVOICE_PDF_FONT_PATH', nil).presence, *FONT_CANDIDATES].compact
      @font_path = candidates
                   .map { |path| path.start_with?('/') ? path : Rails.root.join(path).to_s }
                   .find { |path| File.file?(path) }
    end

    def apply_font(document)
      return unless font_path

      document.font_families.update('InvoiceFont' => { normal: font_path, bold: font_path })
      document.font 'InvoiceFont'
    end

    def text(value)
      return value.to_s if font_path

      I18n.transliterate(value.to_s)
    end

    def add_header(document)
      document.text text("Faktura nr #{@invoice.invoice_number}"), size: 18, style: :bold
      document.move_down 8
      document.text text("Data sprzedaży: #{@invoice.sale_date.to_date}"), size: 10
      document.text text("Termin płatności: #{@invoice.due_date.to_date}"), size: 10
      document.move_down 16
    end

    def add_parties(document)
      document.text text('Nabywca'), size: 11, style: :bold
      document.text text(@invoice.buyer_name), size: 10
      document.text text("NIP: #{@invoice.buyer_tax_id}"), size: 10 if @invoice.buyer_tax_id.present?
      document.text text(@invoice.full_address), size: 10
      document.move_down 16
    end

    def add_items_table(document)
      document.table(table_data, header: true, width: document.bounds.width, cell_style: { size: 8 }) do
        row(0).font_style = :bold
        row(0).background_color = 'DDDDDD'
      end
      document.move_down 12
    end

    def table_data
      rows = @invoice.invoice_items.each_with_index.map { |item, index| format_item(item, index) }

      [HEADERS.map { |header| text(header) }] + rows
    end

    def format_item(item, index)
      [
        index + 1,
        text(item.name),
        item.quantity,
        text(item.unit_of_measure),
        money(item.net_price),
        money(item.total_net_price),
        percentage(item.vat_rate),
        money(item.total_gross_price)
      ]
    end

    def add_totals(document)
      document.text text("Razem netto: #{money(@invoice.total_net)}"), size: 10, align: :right
      document.text text("VAT: #{money(@invoice.tax_value)}"), size: 10, align: :right
      document.text text("Razem brutto: #{money(@invoice.total_gross)}"), size: 12, style: :bold, align: :right
    end

    def money(value) = text(format('%.2f zl', value))
    def percentage(rate) = text("#{(rate * 100).to_i}%")
  end
end
