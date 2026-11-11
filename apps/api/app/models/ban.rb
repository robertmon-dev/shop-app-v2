# frozen_string_literal: true

class Ban < ApplicationRecord
  belongs_to :user, class_name: 'User', foreign_key: 'owner_id'

  validates :permanent, presence: true
  validates :expires_at, presence: false
end
