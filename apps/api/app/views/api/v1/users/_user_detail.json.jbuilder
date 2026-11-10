# frozen_string_literal: true

json.cache! ['user_detail_partial', user_detail.id, user_detail.updated_at] do
  json.id user_detail.id
  json.name user_detail.name
  json.first_name user_detail.first_name
  json.last_name user_detail.last_name
  json.created_at user_detail.created_at
  json.updated_at user_detail.updated_at
end
