# frozen_string_literal: true

class ActivationCode < ApplicationRecord
  belongs_to :user

  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :expires_at, presence: true
end
