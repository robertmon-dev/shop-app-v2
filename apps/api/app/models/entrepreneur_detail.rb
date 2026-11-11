# frozen_string_literal: true

class EntrepreneurDetail < ApplicationRecord
  belongs_to :user_detail

  validates :nip, uniqueness: { allow_nil: true }
  validates :krs, uniqueness: { allow_nil: true }
  validates :income, :costs, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
end
