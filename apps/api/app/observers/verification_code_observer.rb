# frozen_string_literal: true

class VerificationCodeObserver < ApplicationObserver
  observe :verification_code

  def after_create(verification_code)
    Rails.logger.info "VerificationCodeObserver: New verification code created (ID: #{verification_code.id}, User ID: #{verification_code.user.id})"
  end

  def after_destroy(verification_code)
    Rails.logger.info "VerificationCodeObserver: Verification code deleted (ID: #{verification_code.id}, User ID: #{verification_code.user.id})"
  end
end
