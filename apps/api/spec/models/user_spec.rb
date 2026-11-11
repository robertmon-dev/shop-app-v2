# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  subject { build(:user) }

  describe 'associations' do
    it { should have_one(:user_detail).dependent(:destroy) }
    it { should have_one(:user_settings).dependent(:destroy) }
    it { should have_one(:activation_code).dependent(:destroy) }
    it { should have_one(:verification_code).dependent(:destroy) }
    it { should have_one(:second_factor_code).dependent(:destroy) }
    it { should have_one(:reset_code).dependent(:destroy) }
    it { should have_many(:user_actions).dependent(:destroy) }
    it { should have_many(:orders).dependent(:destroy) }
    it { should have_many(:blacklisted_tokens).with_foreign_key(:owner_id).dependent(:destroy) }
    it { should have_many(:comments).dependent(:destroy) }
    it { should have_many(:cart_items).class_name('Item').dependent(:destroy) }

    it { should accept_nested_attributes_for(:user_detail) }
  end

  describe 'validations' do
    it { should validate_presence_of(:mail) }
    it { should validate_uniqueness_of(:mail) }
    it { should validate_presence_of(:password_digest) }
    it { should validate_uniqueness_of(:phone).case_insensitive.allow_nil }
    it { should have_secure_password }
  end

  describe 'enums' do
    it { should define_enum_for(:role).with_values(%w[regular moderator admin entrepreneur]).with_default(:regular) }
  end

  describe '#create_activation_code!' do
    let(:user) { create(:user) }
    let(:code) { 'ACTIVATION123' }

    it 'creates an activation code for the user' do
      expect { user.create_activation_code!(code: code) }.to change(ActivationCode, :count).by(1)

      activation_code = user.reload.activation_code
      expect(activation_code).to be_present
      expect(activation_code.code).to eq(code)
      expect(activation_code.expires_at).to be_within(1.minute).of(24.hours.from_now)
    end
  end

  describe '#create_reset_code!' do
    let(:user) { create(:user) }
    let(:code) { 'RESET123' }

    it 'creates a reset code for the user' do
      expect { user.create_reset_code!(code: code, expires_in_minutes: 15) }.to change(ResetCode, :count).by(1)

      reset_code = user.reload.reset_code
      expect(reset_code).to be_present
      expect(reset_code.code).to eq(code)
      expect(reset_code.expires_at).to be_within(1.minute).of(15.minutes.from_now)
    end
  end

  describe '#accessible_by?' do
    let(:user) { create(:user, role: :regular) }
    let(:another_user) { create(:user, role: :regular) }
    let(:admin) { create(:user, role: :admin) }

    context 'when the other user is an admin' do
      it 'returns true' do
        expect(user.accessible_by?(admin)).to be true
      end
    end

    context 'when the other user is the same user' do
      it 'returns true' do
        expect(user.accessible_by?(user)).to be true
      end
    end

    context 'when the other user is a different regular user' do
      it 'returns false' do
        expect(user.accessible_by?(another_user)).to be false
      end
    end

    context 'when the other user is nil' do
      it 'returns false' do
        expect(user.accessible_by?(nil)).to be false
      end
    end
  end

  describe '#two_factor_enabled?' do
    let(:user) { create(:user) }

    context 'when user has settings with 2FA enabled' do
      before { create(:user_settings, user: user, two_factor: true) }

      it 'returns true' do
        expect(user.two_factor_enabled?).to be true
      end
    end

    context 'when user has settings with 2FA disabled' do
      before { create(:user_settings, user: user, two_factor: false) }

      it 'returns false' do
        expect(user.two_factor_enabled?).to be false
      end
    end

    context 'when user does not have settings' do
      it 'returns nil' do
        expect(user.user_settings).to be_nil
        expect(user.two_factor_enabled?).to be_nil
      end
    end
  end

  describe 'enum role methods' do
    it 'returns true for #admin? when user is an admin' do
      admin_user = build(:user, role: :admin)
      expect(admin_user.admin?).to be true
      expect(admin_user.regular?).to be false
    end

    it 'returns true for #regular? when user is a regular user' do
      regular_user = build(:user, role: :regular)
      expect(regular_user.regular?).to be true
      expect(regular_user.admin?).to be false
    end

    it 'returns true for #moderator? when user is a moderator' do
      moderator_user = build(:user, role: :moderator)
      expect(moderator_user.moderator?).to be true
      expect(moderator_user.regular?).to be false
    end

    it 'aliases #user? to #regular?' do
      regular_user = build(:user, role: :regular)
      expect(regular_user.user?).to be true
    end
  end
end
