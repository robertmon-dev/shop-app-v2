# frozen_string_literal: true

json.filename @data[:filename]
json.content_type 'application/pdf'
json.pdf Base64.strict_encode64(@data[:pdf])
