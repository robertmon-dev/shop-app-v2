# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductRate, type: :model do
  subject { create(:product_rate) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:product) }
  end

  describe 'validations' do
    it { should validate_presence_of(:rating) }
    it { should validate_numericality_of(:rating).only_integer.is_in(1..5) }
    it { should validate_length_of(:comment).is_at_most(1000) }

    it 'validates uniqueness of user_id scoped to product_id' do
      should validate_uniqueness_of(:user_id)
        .scoped_to(:product_id)
        .with_message('has already rated this product')
    end
  end

  describe 'creation' do
    it 'is valid with valid attributes' do
      expect(build(:product_rate)).to be_valid
    end

    it 'is invalid without a rating' do
      expect(build(:product_rate, rating: nil)).not_to be_valid
    end

    it 'is invalid with a rating outside the range (e.g., 0)' do
      expect(build(:product_rate, rating: 0)).not_to be_valid
    end

    it 'is invalid with a rating outside the range (e.g., 6)' do
      expect(build(:product_rate, rating: 6)).not_to be_valid
    end

    it 'is valid with a nil comment' do
      expect(build(:product_rate, comment: nil)).to be_valid
    end

    it 'is invalid with a comment longer than 1000 characters' do
      expect(build(:product_rate, comment: 'a' * 1001)).not_to be_valid
    end
  end
end
