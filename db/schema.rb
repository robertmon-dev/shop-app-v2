# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_11_09_230000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "activation_codes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "code", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_activation_codes_on_code", unique: true
    t.index ["user_id"], name: "index_activation_codes_on_user_id"
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "bans", force: :cascade do |t|
    t.text "reason"
    t.datetime "expires_at"
    t.bigint "user_id", null: false
    t.bigint "owner_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_bans_on_owner_id"
    t.index ["user_id"], name: "index_bans_on_user_id"
  end

  create_table "blacklisted_tokens", force: :cascade do |t|
    t.string "token", null: false
    t.bigint "owner_id", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_blacklisted_tokens_on_expires_at"
    t.index ["owner_id"], name: "index_blacklisted_tokens_on_owner_id"
    t.index ["token"], name: "index_blacklisted_tokens_on_token", unique: true
  end

  create_table "categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.uuid "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
    t.index ["parent_id"], name: "index_categories_on_parent_id"
  end

  create_table "comments", force: :cascade do |t|
    t.uuid "product_id", null: false
    t.bigint "user_id", null: false
    t.text "content", null: false
    t.bigint "parent_id"
    t.integer "replies_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["product_id"], name: "index_comments_on_product_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "entrepreneur_details", force: :cascade do |t|
    t.bigint "user_detail_id", null: false
    t.string "business_name"
    t.string "nip"
    t.string "krs"
    t.text "description"
    t.text "offer"
    t.float "income"
    t.float "costs"
    t.float "funding_capital"
    t.string "industry"
    t.jsonb "management_council_members"
    t.jsonb "decision_makers"
    t.string "business_phone_number"
    t.string "business_mail"
    t.string "website_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["krs"], name: "index_entrepreneur_details_on_krs", unique: true
    t.index ["nip"], name: "index_entrepreneur_details_on_nip", unique: true
    t.index ["user_detail_id"], name: "index_entrepreneur_details_on_user_detail_id", unique: true
  end

  create_table "invoice_items", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.uuid "product_id", null: false
    t.string "name", null: false
    t.integer "quantity", null: false
    t.string "unit_of_measure", default: "szt.", null: false
    t.decimal "net_price", precision: 10, scale: 2, null: false
    t.decimal "vat_rate", precision: 5, scale: 2, null: false
    t.decimal "total_net_price", precision: 10, scale: 2, null: false
    t.decimal "total_vat_price", precision: 10, scale: 2, null: false
    t.decimal "total_gross_price", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_items_on_invoice_id"
    t.index ["product_id"], name: "index_invoice_items_on_product_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "location_id", null: false
    t.bigint "payment_id", null: false
    t.bigint "order_id", null: false
    t.text "url"
    t.text "thumbnail_url"
    t.string "full_address", null: false
    t.string "buyer_name", null: false
    t.string "buyer_tax_id"
    t.datetime "sale_date", null: false
    t.datetime "due_date", null: false
    t.string "invoice_number", null: false
    t.decimal "tax_value", precision: 12, scale: 2, null: false
    t.decimal "total_gross", precision: 12, scale: 2, null: false
    t.decimal "total_net", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_number"], name: "index_invoices_on_invoice_number", unique: true
    t.index ["location_id"], name: "index_invoices_on_location_id"
    t.index ["order_id"], name: "index_invoices_on_order_id"
    t.index ["payment_id"], name: "index_invoices_on_payment_id"
    t.index ["user_id"], name: "index_invoices_on_user_id"
  end

  create_table "items", force: :cascade do |t|
    t.bigint "order_id"
    t.bigint "user_id"
    t.uuid "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "price_at_purchase", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_items_on_order_id"
    t.index ["product_id"], name: "index_items_on_product_id"
    t.index ["user_id"], name: "index_items_on_user_id"
  end

  create_table "locations", force: :cascade do |t|
    t.bigint "user_detail_id"
    t.string "country", null: false
    t.string "province", null: false
    t.string "city", null: false
    t.string "postal_code", null: false
    t.string "street"
    t.integer "building_number"
    t.integer "apartment_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_detail_id"], name: "index_locations_on_user_detail_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "location_id", null: false
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0"
    t.integer "status", default: 0
    t.integer "payment_status", default: 0
    t.datetime "order_date", null: false
    t.integer "package_carrier"
    t.text "transaction_id"
    t.string "package_type"
    t.text "notes"
    t.integer "shipping_service_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_payment_intent_id"
    t.index ["location_id"], name: "index_orders_on_location_id"
    t.index ["stripe_payment_intent_id"], name: "index_orders_on_stripe_payment_intent_id", unique: true
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.integer "status", default: 0, null: false
    t.string "payment_method", null: false
    t.string "stripe_payment_intent_id"
    t.string "currency", null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_charge_id"
    t.index ["order_id"], name: "index_payments_on_order_id"
    t.index ["stripe_charge_id"], name: "index_payments_on_stripe_charge_id", unique: true
    t.index ["stripe_payment_intent_id"], name: "index_payments_on_stripe_payment_intent_id", unique: true
  end

  create_table "product_categories", id: false, force: :cascade do |t|
    t.uuid "product_id", null: false
    t.uuid "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_product_categories_on_category_id"
    t.index ["product_id", "category_id"], name: "index_product_categories_on_product_id_and_category_id", unique: true
    t.index ["product_id"], name: "index_product_categories_on_product_id"
  end

  create_table "product_likes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.uuid "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_likes_on_product_id"
    t.index ["user_id", "product_id"], name: "index_product_likes_on_user_id_and_product_id", unique: true
    t.index ["user_id"], name: "index_product_likes_on_user_id"
  end

  create_table "product_photos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "url"
    t.text "thumbnail_url"
    t.uuid "product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_photos_on_product_id"
  end

  create_table "product_rates", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.uuid "product_id", null: false
    t.integer "rating", null: false
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_rates_on_product_id"
    t.index ["user_id", "product_id"], name: "index_product_rates_on_user_id_and_product_id", unique: true
    t.index ["user_id"], name: "index_product_rates_on_user_id"
  end

  create_table "products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.decimal "vat_rate", precision: 5, scale: 2, null: false
    t.string "unit_of_measure", default: "szt.", null: false
    t.decimal "weight_kg", precision: 10, scale: 2, null: false
    t.decimal "height_cm", precision: 10, scale: 2, null: false
    t.decimal "width_cm", precision: 10, scale: 2, null: false
    t.decimal "length_cm", precision: 10, scale: 2, null: false
    t.string "product_type"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "refunds", force: :cascade do |t|
    t.text "description", null: false
    t.text "reason", null: false
    t.integer "status", default: 0, null: false
    t.integer "payment_status", default: 0, null: false
    t.datetime "refund_date"
    t.bigint "user_id"
    t.bigint "order_id"
    t.bigint "payment_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_refunds_on_order_id"
    t.index ["payment_id"], name: "index_refunds_on_payment_id"
    t.index ["user_id"], name: "index_refunds_on_user_id"
  end

  create_table "reset_codes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "code", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_reset_codes_on_code", unique: true
    t.index ["user_id"], name: "index_reset_codes_on_user_id"
  end

  create_table "second_factor_codes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "code", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_second_factor_codes_on_code", unique: true
    t.index ["user_id"], name: "index_second_factor_codes_on_user_id"
  end

  create_table "user_actions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "action_type", null: false
    t.string "action", null: false
    t.text "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_actions_on_user_id"
  end

  create_table "user_details", force: :cascade do |t|
    t.string "name", null: false
    t.string "first_name"
    t.string "last_name"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_details_on_user_id", unique: true
  end

  create_table "user_settings", force: :cascade do |t|
    t.boolean "two_factor", default: false, null: false
    t.boolean "night_mode", default: false, null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_settings_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "mail", null: false
    t.string "password_digest", null: false
    t.string "phone"
    t.integer "role", default: 0, null: false
    t.boolean "active", default: false, null: false
    t.boolean "verified", default: false, null: false
    t.boolean "two_factor_enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mail"], name: "index_users_on_mail", unique: true
    t.index ["phone"], name: "index_users_on_phone", unique: true, where: "(phone IS NOT NULL)"
  end

  create_table "verification_codes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "code", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_verification_codes_on_code", unique: true
    t.index ["user_id"], name: "index_verification_codes_on_user_id"
  end

  add_foreign_key "activation_codes", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bans", "users"
  add_foreign_key "bans", "users", column: "owner_id"
  add_foreign_key "blacklisted_tokens", "users", column: "owner_id"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "products"
  add_foreign_key "comments", "users"
  add_foreign_key "entrepreneur_details", "user_details"
  add_foreign_key "invoice_items", "invoices"
  add_foreign_key "invoice_items", "products"
  add_foreign_key "invoices", "locations"
  add_foreign_key "invoices", "orders"
  add_foreign_key "invoices", "payments"
  add_foreign_key "invoices", "users"
  add_foreign_key "items", "orders"
  add_foreign_key "items", "products"
  add_foreign_key "items", "users"
  add_foreign_key "locations", "user_details"
  add_foreign_key "orders", "locations"
  add_foreign_key "orders", "users"
  add_foreign_key "payments", "orders"
  add_foreign_key "product_categories", "categories"
  add_foreign_key "product_categories", "products"
  add_foreign_key "product_likes", "products"
  add_foreign_key "product_likes", "users"
  add_foreign_key "product_photos", "products"
  add_foreign_key "product_rates", "products"
  add_foreign_key "product_rates", "users"
  add_foreign_key "refunds", "orders"
  add_foreign_key "refunds", "payments"
  add_foreign_key "refunds", "users"
  add_foreign_key "reset_codes", "users"
  add_foreign_key "second_factor_codes", "users"
  add_foreign_key "user_actions", "users"
  add_foreign_key "user_details", "users"
  add_foreign_key "user_settings", "users"
  add_foreign_key "verification_codes", "users"
end
