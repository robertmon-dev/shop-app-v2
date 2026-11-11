# frozen_string_literal: true

class ResetCode < ApplicationRecord
  belongs_to :user

  validates :code, presence: true, uniqueness: true
  validates :expires_at, presence: true
end
