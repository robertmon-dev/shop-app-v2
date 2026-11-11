# frozen_string_literal: true

class Location < ApplicationRecord
  belongs_to :user_detail, optional: true
  belongs_to :invoice, optional: true

  validates :country, :province, :city, :postal_code, presence: true
  validates :building_number, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :apartment_number, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }

  def full_address
    address_parts = [
      street_with_numbers,
      "#{postal_code} #{city}",
      "#{country}, #{province}"
    ]
    address_parts.compact_blank.join("\n")
  end

  def street_with_numbers
    return nil if building_number.blank?

    [street, building_number, apartment_number].compact.join(' ')
  end
end
