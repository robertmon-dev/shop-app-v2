# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentObserver do
  let(:order) { create(:order) }

  it 'enqueues invoice creation when a payment is created already paid' do
    expect { create(:payment, :paid, order: order) }
      .to have_enqueued_job(InvoiceCreationJob).once
  end

  it 'enqueues invoice creation when an unpaid payment becomes paid' do
    payment = create(:payment, order: order)

    expect { payment.mark_as_paid! }.to have_enqueued_job(InvoiceCreationJob).with(payment)
  end

  it 'does not enqueue anything for an unpaid payment' do
    expect { create(:payment, order: order) }.not_to have_enqueued_job(InvoiceCreationJob)
  end

  it 'does not enqueue another invoice when a paid payment is refunded' do
    payment = create(:payment, :paid, order: order)

    expect { payment.mark_as_refunded! }.not_to have_enqueued_job(InvoiceCreationJob)
  end

  it 'does not enqueue another invoice when an unrelated attribute of a paid payment changes' do
    payment = create(:payment, :paid, order: order)

    expect { payment.update!(error_message: 'note') }.not_to have_enqueued_job(InvoiceCreationJob)
  end
end
