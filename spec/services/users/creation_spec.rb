# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Services::UserCreationService, type: :service do
  let(:valid_params) do
    {
      mail: 'new.user@example.com',
      phone: '123456789',
      password: 'password123',
      password_confirmation: 'password123'
    }
  end

  describe '.call' do
    context 'with valid and unique parameters' do
      it 'creates a new user' do
        expect do
          described_class.call(valid_params)
        end.to change(User, :count).by(1)
      end

      it 'creates an activation code for the new user' do
        expect do
          described_class.call(valid_params)
        end.to change(ActivationCode, :count).by(1)
        expect(User.last.activation_code).not_to be_nil
      end

      it 'returns a successful result' do
        result = described_class.call(valid_params)
        expect(result.success?).to be true
        expect(result.status).to eq(:created)
        expect(result.data[:user]).to be_a(User)
        expect(result.data[:user].mail).to eq('new.user@example.com')
      end
    end

    context 'when the email is already taken' do
      before { create(:user, mail: valid_params[:mail]) }

      it 'does not create a new user' do
        expect do
          described_class.call(valid_params)
        end.not_to change(User, :count)
      end

      it 'returns a conflict failure result' do
        result = described_class.call(valid_params)
        expect(result.success?).to be false
        expect(result.status).to eq(:conflict)
      end
    end

    context 'when the phone number is already taken' do
      before { create(:user, phone: valid_params[:phone]) }

      it 'does not create a new user' do
        expect do
          described_class.call(valid_params)
        end.not_to change(User, :count)
      end

      it 'returns a conflict failure result' do
        result = described_class.call(valid_params)
        expect(result.success?).to be false
        expect(result.status).to eq(:conflict)
        expect(result.errors.first).to eq('User with this phone already exists')
      end
    end

    context 'when parameters fail model validation' do
      let(:invalid_params) { valid_params.merge(password_confirmation: 'wrong') }

      it 'does not create a new user' do
        expect do
          described_class.call(invalid_params)
        end.not_to change(User, :count)
      end

      it 'returns an unprocessable_content result' do
        result = described_class.call(invalid_params)
        expect(result.success?).to be false
        expect(result.status).to eq(:unprocessable_content)
        expect(result.errors).to include("Password confirmation doesn't match Password")
      end
    end
  end
end
