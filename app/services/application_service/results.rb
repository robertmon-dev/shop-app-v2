# frozen_string_literal: true

module Services
  module Concerns
    module ResultHelpers
      def stripe_error_result(exc)
        Services::Result.new(
          success?: false,
          errors: ['Could not connect to the payment provider. Please try again later.'],
          status: :service_unavailable,
          message: exc.message
        )
      end

      def no_action_needed_result(message:)
        Rails.logger.info "Webhook: #{message}"
        Services::Result.new(
          success?: true,
          status: :ok,
          message: message
        )
      end

      def wrong_refund_status_result(refund:)
        Services::Result.new(
          success?: false,
          errors: ["Cannot cancel refund with status: #{refund.status}"],
          status: :unprocessable_content,
          message: "Cannot cancel refund with status: #{refund.status}."
        )
      end

      def internal_server_error_result(message:, errors:)
        Rails.logger.error "Internal server error #{message}"
        Services::Result.new(
          success?: false,
          errors: errors,
          status: :internal_server_error,
          message: message
        )
      end

      def log_and_return_success_result(message)
        Rails.logger.info "Webhook: #{message}"
        Services::Result.new(
          success?: true,
          status: :ok,
          message: message
        )
      end

      def user_not_found_result
        Services::Result.new(
          success?: false,
          errors: ['User not found.'],
          status: :not_found,
          message: 'User not found.'
        )
      end

      def record_not_destroyed_error_result(exc:, record:)
        Services::Result.new(
          success?: false,
          errors: record.errors.full_messages,
          status: :not_modified,
          message: exc.message
        )
      end

      def not_found_result(errors:, message:)
        Services::Result.new(
          success?: false,
          errors: errors,
          status: :not_found,
          message: message
        )
      end

      def forbidden_result(errors:, message:)
        Services::Result.new(
          success?: false,
          errors: errors,
          status: :forbidden,
          message: message
        )
      end

      def invalid_code_result(message_context:)
        Services::Result.new(
          success?: false,
          errors: ["Invalid or expired #{message_context} code."],
          status: :unprocessable_content,
          message: "Account #{message_context} failed: invalid or expired code."
        )
      end

      def bad_request(errors:, message:)
        Rails.logger.error("Failed to resolve request: #{message}")
        Services::Result.new(
          success?: false,
          errors: errors,
          status: :not_found,
          message: message
        )
      end

      def user_already_activated_result
        Services::Result.new(
          success?: false,
          errors: ['User is already activated'],
          status: :not_acceptable,
          message: 'User is already activated'
        )
      end

      def unknown_error_result(exc)
        Rails.logger.error("An unexpected error occurred: #{exc.message || 'unknownerror'}")
        Services::Result.new(
          success?: false,
          errors: ['Unknown error has occured during the operation'],
          status: :internal_server_error,
          message: ''
        )
      end

      def invalid_record_result(exc)
        Rails.logger.error("Validation failed: #{exc.message}")
        Services::Result.new(
          success?: false,
          errors: exc.record&.errors&.full_messages || [],
          status: :unprocessable_content,
          message: 'Validation failed'
        )
      end

      def success_result(data:, message:, status: :ok)
        Rails.logger.info("Successfully finished operation: #{message}")
        Services::Result.new(
          success?: true,
          data: data,
          status: status,
          message: message
        )
      end

      def unprocessable_content_result(record:, message:)
        Rails.logger.error("Failed to validate processing data: #{message}")
        Services::Result.new(
          success?: false,
          errors: record.errors.full_messages,
          status: :unprocessable_content,
          message: message
        )
      end

      def unprocessable_content_with_errors_result(errors:, message:)
        Services::Result.new(
          success?: false,
          errors: errors,
          status: :unprocessable_content,
          message: message
        )
      end

      def destroy_success_result(message:)
        Rails.logger.info("Record destroyed: #{message}")
        Services::Result.new(
          success?: true,
          status: :no_content,
          message: message
        )
      end

      def unauthorized_result(errors:, message:)
        Rails.logger.info("User is not authorized for this action: #{message}")
        Services::Result.new(
          success?: false,
          status: :unauthorized,
          errors: errors,
          message: message
        )
      end

      def conflict_result(errors:, message:)
        Rails.logger.error("Failed to process transaction, data already present in database: #{message}")
        Services::Result.new(
          success?: false,
          errors: errors,
          status: :conflict,
          message: message
        )
      end

      def json_parser_error_result(errors:, message:)
        Rails.logger.error("Stripe Webhook Error: Invalid payload - #{message}")
        Services::Result.new(
          success?: false,
          errors: errors,
          status: :bad_request,
          message: message
        )
      end

      def stripe_verification_error_result(errors:, message:)
        Rails.logger.error("Stripe Webhook Error: Signature verification failed - #{message}")
        Services::Result.new(
          success?: false,
          errors: errors,
          status: :bad_request,
          message: message
        )
      end
    end
  end
end
