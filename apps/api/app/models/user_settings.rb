# frozen_string_literal: true

class UserSettings < ApplicationRecord
  belongs_to :user

  validates :two_factor, inclusion: { in: [true, false] }
  validates :night_mode, inclusion: { in: [true, false] }
end
