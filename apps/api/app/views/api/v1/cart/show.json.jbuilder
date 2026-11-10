# frozen_string_literal: true

json.total_amount @total_amount
json.items_count @items_count
json.items @cart_items, partial: 'api/v1/cart/item', as: :item
