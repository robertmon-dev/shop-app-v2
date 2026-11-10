# frozen_string_literal: true

class User < ApplicationRecord
  enum :role, { regular: 0, moderator: 1, admin: 2, entrepreneur: 3 }, default: :regular
  alias user? regular?
  has_secure_password

  has_one :user_detail, dependent: :destroy
  has_one :user_settings, dependent: :destroy
  has_one :activation_code, dependent: :destroy
  has_one :verification_code, dependent: :destroy
  has_one :second_factor_code, dependent: :destroy
  has_one :reset_code, dependent: :destroy
  has_many :user_actions, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :blacklisted_tokens, foreign_key: :owner_id, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :cart_items, -> { where(order_id: nil) }, class_name: 'Item', dependent: :destroy
  has_many :bans, foreign_key: :owner_id, dependent: :destroy
  has_many :refunds
  has_many :invoices

  accepts_nested_attributes_for :user_detail

  validates :mail, presence: true, uniqueness: true
  validates :phone, uniqueness: { case_sensitive: false }, if: :phone_changed_and_present?
  validates :password_digest, presence: true

  def activated?
    active
  end

  def unactivated?
    !activated?
  end

  def verified?
    verified
  end

  def unverified?
    !verified?
  end

  def create_activation_code!(code:, expires_in_hours: 24)
    activation_code = ActivationCode.new(user: self, code: code, expires_at: expires_in_hours.hours.from_now)
    activation_code.save!
  end

  def create_reset_code!(code:, expires_in_minutes: 15, expires_at: nil)
    final_expires_at = expires_at || expires_in_minutes.minutes.from_now
    reset_code = ResetCode.new(user: self, code: code, expires_at: final_expires_at)
    reset_code.save!
    reset_code
  end

  def create_verification_code!(code:, expires_in_minutes: 15)
    verification_code = VerificationCode.new(user: self, code: code, expires_at: expires_in_minutes.minutes.from_now)
    verification_code.save!
    verification_code
  end

  def accessible_by?(other_user)
    other_user&.admin? || id == other_user&.id
  end

  def two_factor_enabled?
    user_settings&.two_factor
  end

  def phone_changed_and_present?
    phone.present? && phone_changed?
  end
end
