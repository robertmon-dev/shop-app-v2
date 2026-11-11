# frozen_string_literal: true

require 'rails_helper'
RSpec.describe ProductLike, type: :model do
  subject { create(:product_like) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:product) }
  end

  describe 'validations' do
    it 'validates uniqueness of user_id scoped to product_id' do
      should validate_uniqueness_of(:user_id)
        .scoped_to(:product_id)
        .with_message('has already liked this product')
    end
  end

  describe 'creation' do
    it 'is valid with valid attributes' do
      expect(build(:product_like)).to be_valid
    end

    it 'is invalid without a user' do
      expect(build(:product_like, user: nil)).not_to be_valid
    end

    it 'is invalid without a product' do
      expect(build(:product_like, product: nil)).not_to be_valid
    end

    it 'is invalid if the same user likes the same product twice' do
      user = create(:user)
      product = create(:product)
      create(:product_like, user: user, product: product)

      duplicate_like = build(:product_like, user: user, product: product)
      expect(duplicate_like).not_to be_valid
      expect(duplicate_like.errors[:user_id]).to include('has already liked this product')
    end
  end
end
