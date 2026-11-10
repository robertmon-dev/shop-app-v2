class RefundObserver < ApplicationObserver
  observe :refund

  def after_update(refund)
    nil unless refund.status_refunded?
  end
end
