# frozen_string_literal: true

json.cache! ['user_show', @user, @user.user_detail, @user.user_detail&.locations,
             @user.user_detail&.entrepreneur_detail] do
  json.user do
    json.partial! 'api/v1/users/user_data', user: @user

    if @user.user_detail.present?
      json.user_detail do
        json.partial! 'api/v1/users/user_detail', user_detail: @user.user_detail

        if @user.user_detail.locations.present?
          json.locations @user.user_detail.locations do |location|
            json.partial! 'api/v1/users/location', location: location
          end
        end

        if @user.user_detail.entrepreneur_detail.present?
          json.entrepreneur_detail do
            json.partial! 'api/v1/users/entrepreneur_details',
                          entrepreneur_detail: @user.user_detail.entrepreneur_detail
          end
        end
      end
    end
  end
end
