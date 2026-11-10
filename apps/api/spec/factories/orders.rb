# frozen_string_literal: true

FactoryBot.define do
  factory :order do
    association :user
    status { :pending }
    payment_status { :unpaid }
    association :location

    trait :with_items do
      transient do
        items_count { 2 }
      end

      after(:create) do |order, evaluator|
        create_list(:item, evaluator.items_count, order: order, price_at_purchase: 99.99)
        order.reload
        order.save!
      end
    end

    trait :paid do
      payment_status { :paid }

      after(:create) do |order|
        create(:payment, :paid, order: order, amount: order.total_amount)
      end
    end

    trait :shipped do
      status { :shipped }
    end

    trait :delivered do
      status { :delivered }
      payment_status { :paid }
    end
  end

  factory :item do
    association :product
    association :order
    quantity { 1 }
    price_at_purchase { product.price }

    trait :in_cart do
      order { nil }
      association :user
    end
  end

  factory :cart_item, class: 'Item' do
    association :user
    association :product
    quantity { 1 }
    price_at_purchase { product.price }
    order { nil }
  end
end

FactoryBot.define do
  factory :invoice do
    association :user
    association :order
    association :payment
    association :location

    sequence(:invoice_number) { |n| "FV/2026/01/#{n}" }
    buyer_name { 'Test Buyer' }
    buyer_tax_id { '1234567890' }
    full_address { 'Testowa 1, 00-001 Warsaw, Poland' }
    sale_date { Time.current }
    due_date { 14.days.from_now }
    total_net { 100.00 }
    tax_value { 23.00 }
    total_gross { 123.00 }
  end

  factory :invoice_item do
    association :invoice
    association :product

    name { 'Test Item' }
    quantity { 2 }
    unit_of_measure { 'szt.' }
    net_price { 50.00 }
    vat_rate { 0.23 }
    total_net_price { 100.00 }
    total_vat_price { 23.00 }
    total_gross_price { 123.00 }
  end
end
