# frozen_string_literal: true

json.user do
  json.partial! 'api/v1/users/user', user: @user
end
