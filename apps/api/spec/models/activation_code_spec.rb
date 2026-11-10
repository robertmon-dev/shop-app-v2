# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivationCode, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    subject { create(:activation_code) }

    let!(:user) { create(:user) }

    it { should validate_presence_of(:code) }
    it { should validate_uniqueness_of(:code).case_insensitive }

    it { should validate_presence_of(:expires_at) }

    context 'code uniqueness' do
      let!(:existing_activation_code) { create(:activation_code, user: user, code: 'UNIQUECODE123') }

      it 'is valid with a unique code' do
        new_code = build(:activation_code, user: create(:user), code: 'ANOTHERCODE456')
        expect(new_code).to be_valid
      end

      it 'is invalid with a duplicate code (case-sensitive)' do
        duplicate_code = build(:activation_code, user: create(:user), code: 'UNIQUECODE123')
        expect(duplicate_code).not_to be_valid
        expect(duplicate_code.errors[:code]).to include('has already been taken')
      end

      it 'is invalid with a duplicate code (case-insensitive)' do
        duplicate_code = build(:activation_code, user: create(:user), code: 'uniquecode123')
        expect(duplicate_code).not_to be_valid
        expect(duplicate_code.errors[:code]).to include('has already been taken')
      end
    end

    context 'expires_at presence' do
      it 'is valid with an expires_at date' do
        activation_code = build(:activation_code, expires_at: 1.hour.from_now)
        expect(activation_code).to be_valid
      end

      it 'is invalid without an expires_at date' do
        activation_code = build(:activation_code, expires_at: nil)
        expect(activation_code).not_to be_valid
        expect(activation_code.errors[:expires_at]).to include("can't be blank")
      end
    end
  end
end
