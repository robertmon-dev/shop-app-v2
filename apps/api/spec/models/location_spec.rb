# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Location, type: :model do
  describe 'associations' do
    it { should belong_to(:user_detail).optional(true) }
  end

  describe 'validations' do
    it { should validate_presence_of(:country) }
    it { should validate_presence_of(:province) }
    it { should validate_presence_of(:city) }
    it { should validate_presence_of(:postal_code) }

    it { should validate_numericality_of(:building_number).only_integer.is_greater_than(0).allow_nil }
    it { should validate_numericality_of(:apartment_number).only_integer.is_greater_than_or_equal_to(0).allow_nil }

    context 'building_number validation' do
      it 'is valid with a positive integer' do
        location = build(:location, building_number: 10)
        expect(location).to be_valid
      end

      it 'is valid with nil' do
        location = build(:location, building_number: nil)
        expect(location).to be_valid
      end

      it 'is invalid with a non-integer' do
        location = build(:location, building_number: 10.5)
        expect(location).not_to be_valid
        expect(location.errors[:building_number]).to include('must be an integer')
      end

      it 'is invalid with zero' do
        location = build(:location, building_number: 0)
        expect(location).not_to be_valid
        expect(location.errors[:building_number]).to include('must be greater than 0')
      end

      it 'is invalid with a negative integer' do
        location = build(:location, building_number: -5)
        expect(location).not_to be_valid
        expect(location.errors[:building_number]).to include('must be greater than 0')
      end
    end

    context 'apartment_number validation' do
      it 'is valid with a positive integer' do
        location = build(:location, apartment_number: 5)
        expect(location).to be_valid
      end

      it 'is valid with zero' do
        location = build(:location, apartment_number: 0)
        expect(location).to be_valid
      end

      it 'is valid with nil' do
        location = build(:location, apartment_number: nil)
        expect(location).to be_valid
      end

      it 'is invalid with a non-integer' do
        location = build(:location, apartment_number: 2.5)
        expect(location).not_to be_valid
        expect(location.errors[:apartment_number]).to include('must be an integer')
      end

      it 'is invalid with a negative integer' do
        location = build(:location, apartment_number: -1)
        expect(location).not_to be_valid
        expect(location.errors[:apartment_number]).to include('must be greater than or equal to 0')
      end
    end
  end
end
