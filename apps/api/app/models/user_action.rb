# frozen_string_literal: true

class UserAction < ApplicationRecord
  belongs_to :user

  validates :action_type, :action, presence: true
end
