# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Products::Stock do
  let!(:tracked) { create(:product, stock_quantity: 5) }
  let!(:untracked) { create(:product, stock_quantity: nil) }

  def in_transaction(&) = ActiveRecord::Base.transaction(&)

  describe '.take!' do
    it 'reduces the stock of tracked products' do
      in_transaction { described_class.take!({ tracked.id => 2 }) }

      expect(tracked.reload.stock_quantity).to eq(3)
    end

    it 'leaves products without a stock figure alone' do
      in_transaction { described_class.take!({ untracked.id => 100 }) }

      expect(untracked.reload.stock_quantity).to be_nil
    end

    it 'allows taking exactly what is left' do
      in_transaction { described_class.take!({ tracked.id => 5 }) }

      expect(tracked.reload.stock_quantity).to eq(0)
    end

    it 'raises when there is not enough and changes nothing' do
      other = create(:product, stock_quantity: 10)

      expect do
        in_transaction { described_class.take!({ other.id => 1, tracked.id => 6 }) }
      end.to raise_error(described_class::Insufficient, /#{tracked.name}: 5 left/)

      expect(other.reload.stock_quantity).to eq(10)
      expect(tracked.reload.stock_quantity).to eq(5)
    end
  end

  describe '.give_back!' do
    it 'returns stock' do
      in_transaction { described_class.give_back!({ tracked.id => 3 }) }

      expect(tracked.reload.stock_quantity).to eq(8)
    end
  end

  describe '.quantities' do
    it 'sums quantities per product' do
      items = [double(product_id: 'a', quantity: 1), double(product_id: 'a', quantity: 2),
               double(product_id: 'b', quantity: 4)]

      expect(described_class.quantities(items)).to eq('a' => 3, 'b' => 4)
    end
  end
end
