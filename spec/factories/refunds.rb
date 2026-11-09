# frozen_string_literal: true

FactoryBot.define do
  factory :refund do
    association :order
    association :user

    reason { 'damaged' }
    description { 'Arrived broken' }
    status { :pending }
    payment_status { :unpaid }
    refund_date { Time.current }

    trait :processing do
      status { :processing }
    end

    trait :refunded do
      status { :refunded }
      payment_status { :refunded }
    end

    trait :cancelled do
      status { :cancelled }
    end
  end
end
