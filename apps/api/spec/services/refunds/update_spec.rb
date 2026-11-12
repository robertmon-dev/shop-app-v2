# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Refunds::Update, type: :service do
  let(:refund) { create(:refund) }

  def update(refund, params) = described_class.new(refund, ActionController::Parameters.new(params).permit!).call

  it 'updates the description without touching the status' do
    result = update(refund, description: 'New text')

    expect(result.success?).to be true
    expect(refund.reload).to have_attributes(description: 'New text', status: 'pending')
  end

  it 'moves a pending refund to processing' do
    expect(update(refund, status: 'processing').success?).to be true
    expect(refund.reload.status).to eq('processing')
  end

  it 'allows rejecting a processing refund' do
    refund.update!(status: :processing)

    expect(update(refund, status: 'rejected').success?).to be true
  end

  %w[refunded cancelled].each do |status|
    it "does not let a refund jump to #{status} without going through Stripe or cancel" do
      result = update(refund, status: status)

      expect(result.success?).to be false
      expect(refund.reload.status).to eq('pending')
    end
  end

  it 'does not reopen a refunded refund' do
    refund = create(:refund, :refunded)

    expect(update(refund, status: 'pending').success?).to be false
  end
end
