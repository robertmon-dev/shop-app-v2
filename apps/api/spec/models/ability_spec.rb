# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ability do
  subject(:ability) { described_class.new(user) }

  let(:own_payment) { create(:payment, order: create(:order, user: user)) }
  let(:foreign_payment) { create(:payment, order: create(:order)) }

  context 'with a verified regular user' do
    let(:user) { create(:user, :with_detail) }

    it 'can list and read only their own payments' do
      expect(ability.can?(:read, own_payment)).to be true
      expect(ability.can?(:read, foreign_payment)).to be false
    end

    it 'scopes accessible payments to their own' do
      own_payment
      foreign_payment

      expect(Payment.accessible_by(ability)).to contain_exactly(own_payment)
    end
  end

  context 'with a moderator' do
    let(:user) { create(:user, :moderator) }

    it 'can read what moderation needs' do
      [Product, Category, Comment, Order, Item, Payment, Refund, Invoice].each do |model|
        expect(ability.can?(:read, model)).to be true
      end
    end

    it 'cannot read users or personal data' do
      expect(ability.can?(:read, create(:user))).to be false
      expect(ability.can?(:read, Ban)).to be false
    end

    it 'still cannot manage everything' do
      expect(ability.can?(:destroy, Order)).to be false
    end
  end

  context 'with an admin' do
    let(:user) { create(:user, :admin) }

    it 'can manage everything' do
      expect(ability.can?(:manage, :all)).to be true
    end
  end
end
