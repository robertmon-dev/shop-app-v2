# frozen_string_literal: true

module Users
  class Creation < ApplicationService
    def initialize(user_params)
      @user_params = user_params
    end

    def call
      conflict = existing_user_conflict
      return conflict if conflict

      with_error_handling do
        ActiveRecord::Base.transaction do
          user = User.create!(@user_params)
          user.create_activation_code!(code: SecureRandom.hex(4))
          success_result(data: { user: user }, message: 'User registered succesfully. Activation code sent',
                         status: :created)
        end
      end
    end

    private

    def existing_user_conflict
      return registration_conflict('email') if User.exists?(mail: @user_params[:mail])
      return unless @user_params[:phone].present? && User.exists?(phone: @user_params[:phone])

      registration_conflict('phone')
    end

    def registration_conflict(field)
      conflict_result(errors: ["User with this #{field} already exists"], message: 'User registration failed')
    end
  end
end
