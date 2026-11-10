# frozen_string_literal: true

json.cache! ['entrepreneur_detail_partial', entrepreneur_detail.id, entrepreneur_detail.updated_at] do
  json.id entrepreneur_detail.id
  json.business_name entrepreneur_detail.business_name
  json.nip entrepreneur_detail.nip
  json.krs entrepreneur_detail.krs
  json.description entrepreneur_detail.description
  json.offer entrepreneur_detail.offer
  json.income entrepreneur_detail.income
  json.costs entrepreneur_detail.costs
  json.funding_capital entrepreneur_detail.funding_capital
  json.industry entrepreneur_detail.industry
  json.management_council_members entrepreneur_detail.management_council_members
  json.decision_makers entrepreneur_detail.decision_makers
  json.business_phone_number entrepreneur_detail.business_phone_number
  json.business_mail entrepreneur_detail.business_mail
  json.website_address entrepreneur_detail.website_address
  json.created_at entrepreneur_detail.created_at
  json.updated_at entrepreneur_detail.updated_at
end
