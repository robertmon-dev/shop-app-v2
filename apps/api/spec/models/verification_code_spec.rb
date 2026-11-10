# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VerificationCode, type: :model do
  subject { create(:verification_code, expires_at: 1.hour.from_now) }

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:code) }
    it { should validate_uniqueness_of(:code) }
    it { should validate_presence_of(:expires_at) }
  end

  describe 'creation' do
    it 'is valid with valid attributes' do
      expect(build(:verification_code, expires_at: 1.hour.from_now)).to be_valid
    end

    it 'is invalid without a user' do
      expect(build(:verification_code, user: nil, expires_at: 1.hour.from_now)).not_to be_valid
    end

    it 'is invalid without a code' do
      expect(build(:verification_code, code: nil, expires_at: 1.hour.from_now)).not_to be_valid
    end

    it 'is invalid without an expiration date' do
      expect(build(:verification_code, expires_at: nil)).not_to be_valid
    end
  end
end
