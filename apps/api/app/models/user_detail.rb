# frozen_string_literal: true

class UserDetail < ApplicationRecord
  belongs_to :user
  has_many :locations, dependent: :destroy
  has_one :entrepreneur_detail, dependent: :destroy

  validates :name, presence: true

  def update_details(params)
    if update(params)
      { status: :ok }
    else
      { errors: errors.full_messages, status: :unprocessable_entity }
    end
  end

  def update_location(location_params)
    location = locations.first || locations.build
    if location.update(location_params)
      { status: :ok }
    else
      { errors: location.errors.full_messages, status: :unprocessable_entity }
    end
  end

  def update_entrepreneur_details(entrepreneur_params)
    entrepreneur = entrepreneur_detail || build_entrepreneur_detail
    if entrepreneur.update(entrepreneur_params)
      { status: :ok }
    else
      { errors: entrepreneur.errors.full_messages, status: :unprocessable_entity }
    end
  end

  def full_name
    "#{first_name} #{last_name}"
  end
end
