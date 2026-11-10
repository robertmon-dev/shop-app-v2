# frozen_string_literal: true

module Users
  class Profile < ApplicationService
    def initialize(user)
      @user = user
    end

    def update_profile(params)
      with_error_handling do
        if @user.update(params)
          success_result(data: { user: @user }, message: 'Profile updated successfully')
        else
          unprocessable_content_result(record: @user, message: 'Failed to update user profile')
        end
      end
    end

    def update_location(location_params)
      with_error_handling do
        location = user_detail.locations.first || user_detail.locations.build

        if location.update(location_params)
          success_result(data: { user: @user.reload, location: location },
                         message: 'Location updated successfully')
        else
          unprocessable_content_result(record: location, message: 'Failed to update location')
        end
      end
    end

    def update_details(user_detail_params)
      with_error_handling do
        if user_detail.update(user_detail_params)
          success_result(data: { user: @user.reload, user_detail: user_detail },
                         message: 'Personal details updated successfully')
        else
          unprocessable_content_result(record: user_detail, message: 'Failed to update personal details')
        end
      end
    end

    def update_entrepreneur_details(entrepreneur_detail_params)
      return not_an_entrepreneur_result unless @user.entrepreneur?

      with_error_handling do
        entrepreneur_detail = user_detail.entrepreneur_detail || user_detail.build_entrepreneur_detail

        if entrepreneur_detail.update(entrepreneur_detail_params)
          success_result(data: { user: @user.reload, entrepreneur_detail: entrepreneur_detail },
                         message: 'Entrepreneur details updated successfully')
        else
          unprocessable_content_result(record: entrepreneur_detail,
                                       message: 'Failed to update entrepreneur details')
        end
      end
    end

    def destroy_user
      with_error_handling do
        @user.destroy!
        destroy_success_result(message: 'User account deleted successfully')
      end
    end

    def update_role(new_role)
      with_error_handling do
        if @user.update(role: new_role)
          success_result(data: { user: @user }, message: "User role updated to #{new_role} successfully")
        else
          unprocessable_content_result(record: @user, message: 'User role update failed')
        end
      end
    end

    private

    def user_detail
      @user_detail ||= @user.user_detail || @user.create_user_detail!(name: @user.mail)
    end

    def not_an_entrepreneur_result
      unauthorized_result(errors: ['User is not an entrepreneur'],
                          message: 'Access denied: user is not an entrepreneur')
    end
  end
end
