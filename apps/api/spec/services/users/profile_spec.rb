# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::Profile, type: :service do
  let(:user) { create(:user, :with_detail) }
  let(:service) { described_class.new(user) }

  describe '#update_profile' do
    it 'updates the user and returns a successful result' do
      result = service.update_profile(phone: '111222333')

      expect(result.success?).to be true
      expect(result.data[:user]).to eq(user)
      expect(user.reload.phone).to eq('111222333')
    end

    it 'returns a validation failure for invalid data' do
      result = service.update_profile(mail: '')

      expect(result.success?).to be false
      expect(result.status).to eq(:unprocessable_content)
      expect(result.errors).to be_present
    end
  end

  describe '#update_location' do
    let(:location_params) do
      { country: 'Poland', province: 'Masovian', city: 'Warsaw', postal_code: '00-001', building_number: 4 }
    end

    it 'creates the first location for the user' do
      expect { service.update_location(location_params) }.to change(Location, :count).by(1)
    end

    it 'returns the location and the reloaded user' do
      result = service.update_location(location_params)

      expect(result.success?).to be true
      expect(result.data[:location]).to be_a(Location)
      expect(result.data[:user]).to eq(user)
    end

    it 'updates the existing location instead of adding another' do
      service.update_location(location_params)

      expect { service.update_location(location_params.merge(city: 'Krakow')) }
        .not_to change(Location, :count)
      expect(user.user_detail.locations.first.reload.city).to eq('Krakow')
    end

    it 'returns a validation failure when required fields are missing' do
      result = service.update_location(country: '', province: '', city: '', postal_code: '')

      expect(result.success?).to be false
      expect(result.status).to eq(:unprocessable_content)
    end

    context 'when the user has no detail yet' do
      let(:user) { create(:user) }

      it 'creates the detail on demand' do
        expect { service.update_location(location_params) }.to change(UserDetail, :count).by(1)
      end
    end
  end

  describe '#update_details' do
    it 'updates the personal details' do
      result = service.update_details(first_name: 'Robert', last_name: 'Mon')

      expect(result.success?).to be true
      expect(user.user_detail.reload.first_name).to eq('Robert')
    end

    it 'returns a validation failure for a blank name' do
      result = service.update_details(name: '')

      expect(result.success?).to be false
      expect(result.status).to eq(:unprocessable_content)
    end
  end

  describe '#update_entrepreneur_details' do
    let(:entrepreneur_params) { { business_name: 'Acme', nip: '1234567890' } }

    context 'when the user is an entrepreneur' do
      let(:user) { create(:user, :with_detail, role: :entrepreneur) }

      it 'creates the entrepreneur details' do
        result = service.update_entrepreneur_details(entrepreneur_params)

        expect(result.success?).to be true
        expect(result.data[:entrepreneur_detail].business_name).to eq('Acme')
      end
    end

    context 'when the user is not an entrepreneur' do
      it 'returns an unauthorized result' do
        result = service.update_entrepreneur_details(entrepreneur_params)

        expect(result.success?).to be false
        expect(result.status).to eq(:unauthorized)
        expect(result.errors).to include('User is not an entrepreneur')
      end
    end
  end

  describe '#update_role' do
    it 'changes the role' do
      result = service.update_role(:moderator)

      expect(result.success?).to be true
      expect(user.reload.moderator?).to be true
    end

    it 'fails for an unknown role' do
      result = service.update_role(:overlord)

      expect(result.success?).to be false
    end
  end

  describe '#destroy_user' do
    it 'destroys the user and returns no_content' do
      service

      expect { service.destroy_user }.to change(User, :count).by(-1)
    end

    it 'returns a successful destroy result' do
      result = service.destroy_user

      expect(result.success?).to be true
      expect(result.status).to eq(:no_content)
    end
  end
end
