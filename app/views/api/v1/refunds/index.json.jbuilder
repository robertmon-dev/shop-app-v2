# frozen_string_literal: true

json.cache! ['refunds_index', @refunds.map(&:id).sort, @refunds.maximum(:updated_at) || Time.current, params[:page]] do
  json.refunds @refunds do |refund|
    json.partial! 'api/v1/refunds/refund', refund: refund
  end

  if @refunds.respond_to?(:current_page)
    json.meta do
      json.current_page @refunds.current_page
      json.next_page @refunds.next_page
      json.prev_page @refunds.prev_page
      json.total_pages @refunds.total_pages
      json.total_count @refunds.total_count
    end
  end
end
