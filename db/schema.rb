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

ActiveRecord::Schema[7.1].define(version: 2026_11_06_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.string "subdomain", null: false
    t.string "status", default: "active", null: false
    t.string "time_zone", default: "Berlin", null: false
    t.string "currency", default: "EUR", null: false
    t.string "locales", default: ["de", "bs", "en"], null: false, array: true
    t.decimal "preset_amounts", default: ["5.0", "10.0", "20.0"], null: false, array: true
    t.boolean "allow_custom_amount", default: true, null: false
    t.boolean "collect_donor_details", default: true, null: false
    t.boolean "show_recent_donations", default: false, null: false
    t.string "primary_color", default: "#23716b", null: false
    t.string "accent_color", default: "#e8a23a", null: false
    t.string "background_color", default: "#12302d", null: false
    t.jsonb "terminal_copy", default: {}, null: false
    t.text "receipt_footer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["subdomain"], name: "index_accounts_on_subdomain", unique: true
  end

  create_table "brand_images", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "kind", null: false
    t.binary "data", null: false
    t.string "content_type", null: false
    t.string "digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "kind"], name: "index_brand_images_on_account_id_and_kind", unique: true
  end

  create_table "donations", force: :cascade do |t|
    t.decimal "amount"
    t.string "currency"
    t.string "donor_name"
    t.string "donor_email"
    t.string "status"
    t.string "checkout_reference"
    t.string "checkout_id"
    t.string "transaction_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.bigint "terminal_id"
    t.boolean "test", default: false, null: false
    t.string "locale"
    t.index ["account_id", "status", "created_at"], name: "index_donations_on_account_id_and_status_and_created_at"
    t.index ["account_id"], name: "index_donations_on_account_id"
    t.index ["checkout_id"], name: "index_donations_on_checkout_id"
    t.index ["terminal_id"], name: "index_donations_on_terminal_id"
  end

  create_table "payment_connections", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "provider", null: false
    t.text "credentials"
    t.string "webhook_token", null: false
    t.datetime "verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "provider"], name: "index_payment_connections_on_account_id_and_provider", unique: true
    t.index ["account_id"], name: "index_payment_connections_on_account_id"
    t.index ["webhook_token"], name: "index_payment_connections_on_webhook_token", unique: true
  end

  create_table "terminals", force: :cascade do |t|
    t.string "slug", null: false
    t.string "provider_reader_id"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.bigint "payment_connection_id", null: false
    t.string "hostname", null: false
    t.boolean "active", default: true, null: false
    t.string "certificate_status"
    t.index ["account_id", "slug"], name: "index_terminals_on_account_id_and_slug", unique: true
    t.index ["account_id"], name: "index_terminals_on_account_id"
    t.index ["hostname"], name: "index_terminals_on_hostname", unique: true
    t.index ["payment_connection_id"], name: "index_terminals_on_payment_connection_id"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "account_id"
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.boolean "admin", default: false, null: false
    t.string "locale"
    t.datetime "last_login_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "email"], name: "index_users_on_account_id_and_email", unique: true
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email"], name: "index_users_on_email_for_admins", unique: true, where: "admin"
  end

  add_foreign_key "brand_images", "accounts"
  add_foreign_key "donations", "accounts"
  add_foreign_key "donations", "terminals"
  add_foreign_key "payment_connections", "accounts"
  add_foreign_key "terminals", "accounts"
  add_foreign_key "terminals", "payment_connections"
  add_foreign_key "users", "accounts"
end
