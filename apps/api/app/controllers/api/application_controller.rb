# frozen_string_literal: true

module Api
  class ApplicationController < ActionController::API
    include ActionView::Layouts
    include Api::Responding

    layout 'api'

    around_action :measure_execution_time
    around_action :handle_exceptions
    before_action :set_default_response_format
    before_action :authenticate_user!

    helper_method :combined_fragment_cache_key
    helper_method :view_cache_dependencies

    class Unauthorized < StandardError; end
    class Forbidden < StandardError; end
    class BadRequest < StandardError; end

    def current_ability
      @current_ability ||= Ability.new(current_user)
    end

    def current_user
      return unless @decoded_jwt_token&.success?

      @current_user ||= User.find_by(id: @decoded_jwt_token&.data&.dig(:payload, :user_id))
    end

    def authorize_admin!
      raise Forbidden, 'Admin access required.' unless current_user&.admin?
    end

    def authenticate_user!
      token_decode_result = Auth::Bearer.decode(bearer_token.to_s)
      return render_unauthenticated(token_decode_result) unless token_decode_result.success?

      @decoded_jwt_token = token_decode_result

      return render_user_not_found unless current_user
      return render_inactive_account unless current_user.active?

      true
    end

    def bind_data(result)
      @success = result.success?
      @status = result.status
      @message = result.message || ''

      if @success
        @data = result.data || {}
        @errors = []
      else
        @data = {}
        @errors = result.errors || []
      end
    end

    def set_user_by_mail
      @user = User.find_by(mail: params[:mail])
      return if @user

      render_failure(message: 'User with this email not found.', status: :not_found)
    end

    protected

    attr_reader :decoded_jwt_token

    def set_default_response_format
      request.format = :json
    end

    private

    def bearer_token
      request.headers['Authorization']&.split&.last
    end

    def render_unauthenticated(result)
      render_failure(message: result.message, errors: result.errors, status: result.status)
      false
    end

    def render_user_not_found
      render_failure(message: 'User not found.', errors: ['Authentication failed: User not found.'],
                     status: :unauthorized)
      false
    end

    def render_inactive_account
      render_failure(message: 'Account not active or verified.',
                     errors: ['User account is not active or verified.'], status: :forbidden)
      false
    end

    def measure_execution_time
      started_at = Time.now
      yield
      duration = (Time.now - started_at).round(2)
      Rails.logger.info "Action #{action_name} from controller #{controller_name} took #{duration} seconds."
    end

    def handle_exceptions
      yield
    rescue CanCan::AccessDenied
      render_failure(message: 'Access denied', errors: ['Not Authorized'], status: :forbidden)
    rescue Api::ApplicationController::Forbidden
      render_failure(message: 'Access denied.', errors: ['Not Authorized'], status: :forbidden)
    rescue Stripe::SignatureVerificationError => e
      render_failure(message: 'Stripe signature verification failed.', errors: [e.message], status: :bad_request)
    rescue ActiveRecord::RecordNotFound => e
      render_failure(message: 'Resource not found.', errors: [e.message], status: :not_found)
    rescue ActiveRecord::RecordInvalid => e
      render_failure(message: 'Validation failed.', errors: e.record.errors.full_messages,
                     status: :unprocessable_content)
    rescue ArgumentError => e
      render_failure(message: 'Bad request parameters.', errors: [e.message], status: :bad_request)
    rescue StandardError => e
      Rails.logger.error e.message.to_s
      render_failure(message: 'Internal server error.', errors: ['An unexpected error occurred.'],
                     status: :internal_server_error)
    end
  end
end
