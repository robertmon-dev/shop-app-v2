# frozen_string_literal: true

module Products
  class Stock
    class Insufficient < StandardError; end

    class << self
      def quantities(items)
        items.group_by(&:product_id).transform_values { |group| group.sum(&:quantity) }
      end

      def take!(quantities) = change!(quantities, -1)
      def give_back!(quantities) = change!(quantities, 1)

      private

      def change!(quantities, sign)
        Product.where(id: quantities.keys).order(:id).lock.each do |product|
          next if product.stock_quantity.nil?

          remaining = product.stock_quantity + (sign * quantities.fetch(product.id))
          if remaining.negative?
            raise Insufficient,
                  "Not enough stock for #{product.name}: #{product.stock_quantity} left."
          end

          product.update!(stock_quantity: remaining)
        end
      end
    end
  end
end
