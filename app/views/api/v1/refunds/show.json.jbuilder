# frozen_string_literal: true

json.refund do
  json.partial! 'api/v1/refunds/refund', refund: @refund
end
