# frozen_string_literal: true

class BlacklistedToken < ApplicationRecord
  belongs_to :owner, class_name: 'User', foreign_key: 'owner_id'

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
end
