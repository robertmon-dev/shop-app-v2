module Services
  class RefundUpdateService
    def self.call(refund:)
      new(refund: refund).call
    end

    def intialize(refund)
      @refund = refund
    end

    def call; end
  end
end
