# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAction, type: :model do
  subject { build(:user_action) }

  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:action_type) }
    it { should validate_presence_of(:action) }
  end

  describe 'creation' do
    it 'is valid with all required attributes' do
      expect(build(:user_action)).to be_valid
    end

    it 'is invalid without a user' do
      expect(build(:user_action, user: nil)).not_to be_valid
    end

    it 'is invalid without an action_type' do
      expect(build(:user_action, action_type: nil)).not_to be_valid
    end

    it 'is invalid without an action' do
      expect(build(:user_action, action: nil)).not_to be_valid
    end
  end
end
