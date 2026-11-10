# frozen_string_literal: true

module Api
  class ApplicationController < ActionController::API
    include Api::Responding

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

      render json: { errors: ['User with this email not found.'] }, status: :not_found
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
      render json: { errors: result.errors, message: result.message }, status: result.status
      false
    end

    def render_user_not_found
      render json: { errors: ['Authentication failed: User not found.'], message: 'User not found.' },
             status: :unauthorized
      false
    end

    def render_inactive_account
      render json: { errors: ['User account is not active or verified.'],
                     message: 'Account not active or verified.' },
             status: :forbidden
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
      render json: { errors: ['Not Authorized'], message: 'Access denied' }, status: :forbidden
    rescue Api::ApplicationController::Forbidden
      render json: { errors: ['Not Authorized'], message: 'Access denied.' }, status: :forbidden
    rescue Stripe::SignatureVerificationError => e
      render json: { errors: [e.message], message: 'Stripe signature verification failed.' }, status: :bad_request
    rescue ActiveRecord::RecordNotFound => e
      render json: { errors: [e.message], message: 'Resource not found.' }, status: :not_found
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages, message: 'Validation failed.' },
             status: :unprocessable_content
    rescue ArgumentError => e
      render json: { errors: [e.message], message: 'Bad request parameters.' }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error e.message.to_s
      render json: { errors: ['An unexpected error occurred.'], message: 'Internal server error.' },
             status: :internal_server_error
    end
  end
end
