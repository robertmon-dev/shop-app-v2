# frozen_string_literal: true

body = yield
data = body.present? && body != 'null' ? JSON.parse(body) : {}

json.success @success != false
json.message @message if @message.present?
json.data data if data.present?

if @pagination
  json.meta do
    json.current_page @pagination.current_page
    json.next_page @pagination.next_page
    json.prev_page @pagination.prev_page
    json.total_pages @pagination.total_pages
    json.total_count @pagination.total_count
  end
end
