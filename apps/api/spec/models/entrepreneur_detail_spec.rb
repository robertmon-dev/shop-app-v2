# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EntrepreneurDetail, type: :model do
  subject { create(:entrepreneur_detail) }
  describe 'associations' do
    it { should belong_to(:user_detail) }
  end

  describe 'validations' do
    it { should validate_uniqueness_of(:nip).allow_nil.case_insensitive }
    it { should validate_uniqueness_of(:krs).allow_nil.case_insensitive }
    it { should validate_numericality_of(:income).is_greater_than_or_equal_to(0).allow_nil }
    it { should validate_numericality_of(:costs).is_greater_than_or_equal_to(0).allow_nil }

    context 'nip uniqueness' do
      let!(:existing_entrepreneur_detail) { create(:entrepreneur_detail, nip: '1234567890') }

      it 'is valid with a unique NIP' do
        new_detail = build(:entrepreneur_detail, nip: '0987654321')
        expect(new_detail).to be_valid
      end

      it 'is valid with a nil NIP' do
        new_detail = build(:entrepreneur_detail, nip: nil)
        expect(new_detail).to be_valid
      end

      it 'is invalid with a duplicate NIP' do
        new_detail = build(:entrepreneur_detail, nip: '1234567890')
        expect(new_detail).not_to be_valid
        expect(new_detail.errors[:nip]).to include('has already been taken')
      end
    end

    context 'krs uniqueness' do
      let!(:existing_entrepreneur_detail) { create(:entrepreneur_detail, krs: '0000123456') }

      it 'is valid with a unique KRS' do
        new_detail = build(:entrepreneur_detail, krs: '0000654321')
        expect(new_detail).to be_valid
      end

      it 'is valid with a nil KRS' do
        new_detail = build(:entrepreneur_detail, krs: nil)
        expect(new_detail).to be_valid
      end

      it 'is invalid with a duplicate KRS' do
        new_detail = build(:entrepreneur_detail, krs: '0000123456')
        expect(new_detail).not_to be_valid
        expect(new_detail.errors[:krs]).to include('has already been taken')
      end
    end

    context 'income numericality' do
      it 'is valid with a positive income' do
        detail = build(:entrepreneur_detail, income: 1000.50)
        expect(detail).to be_valid
      end

      it 'is valid with zero income' do
        detail = build(:entrepreneur_detail, income: 0)
        expect(detail).to be_valid
      end

      it 'is valid with nil income' do
        detail = build(:entrepreneur_detail, income: nil)
        expect(detail).to be_valid
      end

      it 'is invalid with a negative income' do
        detail = build(:entrepreneur_detail, income: -100)
        expect(detail).not_to be_valid
        expect(detail.errors[:income]).to include('must be greater than or equal to 0')
      end

      it 'is invalid with non-numerical income' do
        detail = build(:entrepreneur_detail, income: 'abc')
        expect(detail).not_to be_valid
        expect(detail.errors[:income]).to include('is not a number')
      end
    end

    context 'costs numericality' do
      it 'is valid with positive costs' do
        detail = build(:entrepreneur_detail, costs: 500.25)
        expect(detail).to be_valid
      end

      it 'is valid with zero costs' do
        detail = build(:entrepreneur_detail, costs: 0)
        expect(detail).to be_valid
      end

      it 'is valid with nil costs' do
        detail = build(:entrepreneur_detail, costs: nil)
        expect(detail).to be_valid
      end

      it 'is invalid with negative costs' do
        detail = build(:entrepreneur_detail, costs: -50)
        expect(detail).not_to be_valid
        expect(detail.errors[:costs]).to include('must be greater than or equal to 0')
      end

      it 'is invalid with non-numerical costs' do
        detail = build(:entrepreneur_detail, costs: 'xyz')
        expect(detail).not_to be_valid
        expect(detail.errors[:costs]).to include('is not a number')
      end
    end
  end
end
