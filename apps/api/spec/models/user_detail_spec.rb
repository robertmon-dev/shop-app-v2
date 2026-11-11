# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserDetail, type: :model do
  subject { build(:user_detail) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:locations).dependent(:destroy) }
    it { should have_one(:entrepreneur_detail).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
  end

  describe '#update_details' do
    let(:user_detail) { create(:user_detail, name: 'Old Name') }

    context 'with valid parameters' do
      let(:valid_params) { { name: 'New Name' } }

      it 'updates the user detail attributes' do
        result = user_detail.update_details(valid_params)
        expect(user_detail.reload.name).to eq('New Name')
        expect(result[:status]).to eq(:ok)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) { { name: nil } }

      it 'does not update the user detail and returns errors' do
        result = user_detail.update_details(invalid_params)
        expect(user_detail.reload.name).to eq('Old Name')
        expect(result[:status]).to eq(:unprocessable_entity)
        expect(result[:errors]).to include("Name can't be blank")
      end
    end
  end

  describe '#update_location' do
    let(:user_detail) { create(:user_detail, name: 'Test User Name') }
    let(:valid_location_params) do
      { city: 'Warsaw', country: 'Poland', province: 'Masovian', street: 'Main St', postal_code: '00-001' }
    end
    let(:invalid_location_params) { { city: nil } }

    context 'when user detail does not have a location' do
      it 'creates a new location' do
        expect { user_detail.update_location(valid_location_params) }.to change(Location, :count).by(1)
        expect(user_detail.locations.first.city).to eq('Warsaw')
      end
    end

    context 'when user detail already has a location' do
      let!(:location) do
        user_detail.locations.create!(city: 'Krakow', country: 'Poland', province: 'Lesser Poland', street: 'Florianska',
                                      postal_code: '31-019')
      end

      it 'updates the existing location' do
        expect { user_detail.update_location(valid_location_params) }.not_to change(Location, :count)
        expect(location.reload.city).to eq('Warsaw')
      end
    end

    context 'with invalid location parameters' do
      it 'does not save the location and returns errors' do
        allow_any_instance_of(Location).to receive(:update).and_return(false)
        allow_any_instance_of(Location).to receive_message_chain(:errors,
                                                                 :full_messages).and_return(["City can't be blank"])

        result = user_detail.update_location(invalid_location_params)
        expect(result[:status]).to eq(:unprocessable_entity)
        expect(result[:errors]).to include("City can't be blank")
      end
    end
  end

  describe '#update_entrepreneur_details' do
    let(:user_detail) { create(:user_detail, name: 'Test User Name') }
    let(:valid_entrepreneur_params) { { business_name: 'New Biz' } }
    let(:invalid_entrepreneur_params) { { business_name: nil } }

    context 'when user detail does not have entrepreneur details' do
      it 'creates new entrepreneur details' do
        expect do
          user_detail.update_entrepreneur_details(valid_entrepreneur_params)
        end.to change(EntrepreneurDetail, :count).by(1)
        expect(user_detail.entrepreneur_detail.business_name).to eq('New Biz')
      end
    end

    context 'when user detail already has entrepreneur details' do
      let!(:entrepreneur_detail) { user_detail.create_entrepreneur_detail!(business_name: 'Old Biz') }

      it 'updates the existing entrepreneur details' do
        expect do
          user_detail.update_entrepreneur_details(valid_entrepreneur_params)
        end.not_to change(EntrepreneurDetail, :count)
        expect(entrepreneur_detail.reload.business_name).to eq('New Biz')
      end
    end

    context 'with invalid entrepreneur parameters' do
      it 'does not save the details and returns errors' do
        allow_any_instance_of(EntrepreneurDetail).to receive(:update).and_return(false)
        allow_any_instance_of(EntrepreneurDetail).to receive_message_chain(:errors,
                                                                           :full_messages).and_return(["Business name can't be blank"])

        result = user_detail.update_entrepreneur_details(invalid_entrepreneur_params)
        expect(result[:status]).to eq(:unprocessable_entity)
        expect(result[:errors]).to include("Business name can't be blank")
      end
    end
  end
end
