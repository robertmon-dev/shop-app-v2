# frozen_string_literal: true

json.user do
  json.partial! 'api/v1/users/user', user: @user

  detail = @user.user_detail
  if detail
    json.user_detail { json.partial! 'api/v1/users/user_detail', user_detail: detail }
    json.locations detail.locations, partial: 'api/v1/users/location', as: :location
    if detail.entrepreneur_detail
      json.entrepreneur_detail do
        json.partial! 'api/v1/users/entrepreneur_detail', entrepreneur_detail: detail.entrepreneur_detail
      end
    end
  end
end
