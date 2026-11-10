# frozen_string_literal: true

class ApplicationService
  module Results
    def success_result(message:, data: nil, status: :ok)
      Rails.logger.info("Successfully finished operation: #{message}")
      Result.new(success?: true, data: data, status: status, message: message)
    end

    def failure_result(status:, errors:, message:, log: nil)
      Rails.logger.public_send(*log) if log
      Result.new(success?: false, errors: Array(errors), status: status, message: message)
    end

    def destroy_success_result(message:)
      Rails.logger.info("Record destroyed: #{message}")
      Result.new(success?: true, status: :no_content, message: message)
    end

    def no_action_needed_result(message:)
      Rails.logger.info("Webhook: #{message}")
      Result.new(success?: true, status: :ok, message: message)
    end

    def log_and_return_success_result(message) = no_action_needed_result(message: message)

    def not_found_result(errors:, message:)
      failure_result(status: :not_found, errors: errors, message: message)
    end

    def missing_result(label)
      not_found_result(errors: ["#{label} not found"], message: "#{label} not found")
    end

    def invalid_result(message, errors: [message])
      unprocessable_content_with_errors_result(errors: errors, message: message)
    end

    def forbidden_result(errors:, message:)
      failure_result(status: :forbidden, errors: errors, message: message)
    end

    def conflict_result(errors:, message:)
      failure_result(status: :conflict, errors: errors, message: message,
                     log: [:error, "Failed to process transaction, data already present: #{message}"])
    end

    def unauthorized_result(errors:, message:)
      failure_result(status: :unauthorized, errors: errors, message: message,
                     log: [:info, "User is not authorized for this action: #{message}"])
    end

    def unprocessable_content_with_errors_result(errors:, message:)
      failure_result(status: :unprocessable_content, errors: errors, message: message)
    end

    def unprocessable_content_result(record:, message:)
      failure_result(status: :unprocessable_content, errors: record.errors.full_messages, message: message,
                     log: [:error, "Failed to validate processing data: #{message}"])
    end

    def internal_server_error_result(message:, errors:)
      failure_result(status: :internal_server_error, errors: errors, message: message,
                     log: [:error, "Internal server error #{message}"])
    end

    def invalid_record_result(exc)
      failure_result(status: :unprocessable_content, errors: exc.record&.errors&.full_messages || [],
                     message: 'Validation failed', log: [:error, "Validation failed: #{exc.message}"])
    end

    def unknown_error_result(exc)
      failure_result(status: :internal_server_error, errors: ['Unknown error has occured during the operation'],
                     message: '', log: [:error, "An unexpected error occurred: #{exc.message || 'unknownerror'}"])
    end

    def record_not_destroyed_error_result(exc:, record:)
      failure_result(status: :not_modified, errors: record.errors.full_messages, message: exc.message)
    end

    def stripe_error_result(exc)
      failure_result(status: :service_unavailable, message: exc.message,
                     errors: ['Could not connect to the payment provider. Please try again later.'])
    end

    def json_parser_error_result(errors:, message:)
      failure_result(status: :bad_request, errors: errors, message: message,
                     log: [:error, "Stripe Webhook Error: Invalid payload - #{message}"])
    end

    def stripe_verification_error_result(errors:, message:)
      failure_result(status: :bad_request, errors: errors, message: message,
                     log: [:error, "Stripe Webhook Error: Signature verification failed - #{message}"])
    end

    def user_not_found_result
      not_found_result(errors: ['User not found.'], message: 'User not found.')
    end

    def user_already_activated_result
      failure_result(status: :not_acceptable, errors: ['User is already activated'],
                     message: 'User is already activated')
    end

    def user_already_verified_result
      failure_result(status: :not_acceptable, errors: ['User is already verified'],
                     message: 'User is already verified')
    end

    def invalid_code_result(message_context:)
      failure_result(status: :unprocessable_content, errors: ["Invalid or expired #{message_context} code."],
                     message: "Account #{message_context} failed: invalid or expired code.")
    end

    def wrong_refund_status_result(refund:)
      message = "Cannot cancel refund with status: #{refund.status}"
      unprocessable_content_with_errors_result(errors: [message], message: "#{message}.")
    end
  end
end
