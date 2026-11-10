# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserSettings, type: :model do
  subject { build(:user_settings) }

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_inclusion_of(:two_factor).in_array([true, false]) }
    it { should validate_inclusion_of(:night_mode).in_array([true, false]) }
  end

  describe 'creation' do
    it 'is valid with a user' do
      expect(build(:user_settings)).to be_valid
    end

    it 'is invalid without a user' do
      expect(build(:user_settings, user: nil)).not_to be_valid
    end
  end

  describe 'defaults' do
    it 'defaults two_factor to false' do
      user_settings = UserSettings.new
      expect(user_settings.two_factor).to be false
    end

    it 'defaults night_mode to false' do
      user_settings = UserSettings.new
      expect(user_settings.night_mode).to be false
    end
  end
end
