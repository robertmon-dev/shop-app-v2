# frozen_string_literal: true

json.success local_assigns.fetch(:success, true)
json.message message if local_assigns.key?(:message)
json.errors errors if local_assigns.key?(:errors)
json.data do
  yield(json) if block_given?
end
