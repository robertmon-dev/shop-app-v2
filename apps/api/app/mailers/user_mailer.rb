# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def dial_2fa_code(user, code)
    @user = user
    @code = code
    mail(to: @user.mail, subject: 'Your 2FA code')
  end

  def dial_activation_code(user, code)
    @user = user
    @code = code
    mail(to: @user.mail, subject: 'Activation of your account')
  end

  def dial_reset_code(user, code)
    @user = user
    @code = code
    mail(to: @user.mail, subject: 'Your reset code')
  end

  def dial_notification(user, type); end

  def dial_advertisements(users, type); end
end
