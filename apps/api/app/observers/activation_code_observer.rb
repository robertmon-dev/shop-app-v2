# frozen_string_literal: true

class ActivationCodeObserver < ApplicationObserver
  observe :activation_code

  def after_create(activation_code)
    UserMailer.dial_activation_code(activation_code.user, activation_code.code).deliver_later
    Rails.logger.info "ActivationCodeObserver: New activation code created and email sent (ID: #{activation_code.id}, User ID: #{activation_code.user.id})"
  end

  def after_destroy(activation_code)
    Rails.logger.info "ActivationCodeObserver: Activation code deleted (ID: #{activation_code.id}, User ID: #{activation_code.user.id})"
    Rails.logger.info "ActivationCodeObserver: Activation code as been used (ID: #{activation_code.id}, User ID: #{activation_code.user.id})"
  end
end
