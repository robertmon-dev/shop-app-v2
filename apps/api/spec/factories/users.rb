# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    mail { Faker::Internet.unique.email }
    password { 'password' }
    password_confirmation { 'password' }
    phone { Faker::PhoneNumber.unique.subscriber_number(length: 9) }
    active { true }
    verified { true }
    role { :regular }

    trait :admin do
      role { :admin }
    end

    trait :moderator do
      role { :moderator }
    end

    trait :unactivated do
      active { false }
    end

    trait :unverified do
      verified { false }
    end

    trait :two_factor_enabled do
      after(:create) do |user|
        create(:user_settings, user: user, two_factor: true)
      end
    end

    trait :with_detail do
      after(:create) do |user|
        create(:user_detail, user: user)
      end
    end

    trait :with_location do
      after(:create) do |user|
        detail = user.user_detail || create(:user_detail, user: user)
        create(:location, user_detail: detail)
      end
    end

    trait :with_full_details do
      after(:create) do |user|
        create(:user_detail, user: user, entrepreneur_detail: create(:entrepreneur_detail))
      end
    end
  end

  factory :user_detail do
    user
    name { Faker::Name.name }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
  end

  factory :entrepreneur_detail do
    association :user_detail, factory: :user_detail

    business_name { 'Example Business Inc.' }
    nip { Faker::Number.unique.number(digits: 10).to_s }
    krs { Faker::Number.unique.number(digits: 10).to_s }
    description { Faker::Lorem.paragraph }
    offer { Faker::Lorem.paragraph }
    income { Faker::Number.between(from: 0.0, to: 100_000.0).round(2) }
    costs { Faker::Number.between(from: 0.0, to: 50_000.0).round(2) }
    funding_capital { Faker::Number.between(from: 1000.0, to: 1_000_000.0).round(2) }
    industry { Faker::Company.industry }
    management_council_members { [{ name: Faker::Name.name, role: 'CEO' }] }
    decision_makers { [{ name: Faker::Name.name, position: 'Manager' }] }
    business_phone_number { Faker::PhoneNumber.phone_number }
    business_mail { Faker::Internet.email }
    website_address { Faker::Internet.url }
  end

  factory :user_action do
    association :user
    action_type { 'login' }
    action { 'User logged in successfully' }
  end

  factory :user_settings do
    user
    two_factor { false }
    night_mode { true }
  end

  factory :activation_code do
    association :user
    expires_at { 1.day.from_now }
    code { SecureRandom.hex(16) }
  end

  factory :verification_code do
    user
    code { SecureRandom.hex(16) }
    expires_at { 15.minutes.from_now }
  end

  factory :second_factor_code do
    user
    code { SecureRandom.hex(8) }
    expires_at { 15.minutes.from_now }
  end

  factory :reset_code do
    user
    code { SecureRandom.hex(16) }
    expires_at { 15.minutes.from_now }
  end

  factory :blacklisted_token do
    association :owner, factory: :user
    token { SecureRandom.hex(32) }
    expires_at { 24.hours.from_now }
  end

  factory :location do
    association :user_detail

    country { 'Poland' }
    province { 'Masovian Voivodeship' }
    city { 'Warsaw' }
    postal_code { '00-001' }

    building_number { 10 }
    apartment_number { 5 }
  end
end
