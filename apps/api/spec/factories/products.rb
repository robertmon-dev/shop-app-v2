# frozen_string_literal: true

FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Test Product #{n}" }
    price { Faker::Commerce.price(range: 10..1000.0) }
    description { Faker::Lorem.sentence }
    vat_rate { 0.23 }
    height_cm { 10.5 }
    width_cm { 10.5 }
    length_cm { 10.5 }
    weight_kg { 20 }
  end

  factory :product_photo do
    association :product
    after(:build) do |product_photo|
      unless product_photo.image.attached?
        product_photo.image.attach(
          io: File.open(Rails.root.join('spec/fixtures/files/test_image.png')),
          filename: 'test_image.png',
          content_type: 'image/png'
        )
      end
    end
  end

  factory :product_rate do
    association :user
    association :product
    rating { rand(1..5) }
    comment { Faker::Lorem.sentence }
  end

  factory :product_like do
    association :user
    association :product
  end

  factory :comment do
    association :product
    association :user
    content { Faker::Lorem.sentence }
    parent { nil }
    replies_count { 0 }

    trait :with_parent do
      association :parent, factory: :comment
    end
  end
end
