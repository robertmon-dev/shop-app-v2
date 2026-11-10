# frozen_string_literal: true

module Services
  class UserCreationService
    extend Concerns::ResultHelpers
    extend Concerns::Handlers

    def self.call(user_params)
      conflict = check_user_params(user_params: user_params)
      return conflict if conflict

      with_error_handling do
        ActiveRecord::Base.transaction do
          user = User.new(user_params)
          user.save!
          user.create_activation_code!(code: SecureRandom.hex(4))
          success_result(data: { user: user }, message: 'User registered succesfully. Activation code sent',
                         status: :created)
        end
      end
    end

    def self.check_user_params(user_params:)
      if User.exists?(mail: user_params[:mail])
        return conflict_result(errors: ['User with this email already exists'], message: 'User registration failed')
      end

      return unless user_params[:phone].present? && User.exists?(phone: user_params[:phone])

      conflict_result(errors: ['User with this phone already exists'], message: 'User registration failed')
    end
  end
end
