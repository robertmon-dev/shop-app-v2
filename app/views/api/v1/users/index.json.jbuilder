# frozen_string_literal: true

json.users @users, partial: 'api/v1/users/user', as: :user
