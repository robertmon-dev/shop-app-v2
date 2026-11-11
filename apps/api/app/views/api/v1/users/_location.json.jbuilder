# frozen_string_literal: true

json.cache! ['location_partial', location.id, location.updated_at] do
  json.id location.id
  json.country location.country
  json.province location.province
  json.city location.city
  json.postal_code location.postal_code
  json.street location.street
  json.building_number location.building_number
  json.apartment_number location.apartment_number
  json.created_at location.created_at
  json.updated_at location.updated_at
end
