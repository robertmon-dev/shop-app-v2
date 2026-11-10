# frozen_string_literal: true

class UserObserver < ApplicationObserver
  observe :user

  def after_create(user)
    Rails.logger.info "UserObserver: New user registered (ID: #{user.id}, Mail: #{user.mail})"
  end

  def after_update(user)
    Rails.logger.info "UserObserver: User updated (ID: #{user.id}, Mail: #{user.mail})"
  end

  def after_destroy(user)
    Rails.logger.info "UserObserver: User deleted (ID: #{user.id})"
  end
end
