# frozen_string_literal: true

json.success @success
json.message @message if @message.present?
json.errors @errors if @errors.present?
