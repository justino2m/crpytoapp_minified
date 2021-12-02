# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2020_08_23_154438) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "wallet_id"
    t.bigint "currency_id", null: false
    t.decimal "balance", precision: 25, scale: 10, default: "0.0", null: false
    t.decimal "fees", precision: 25, scale: 10, default: "0.0", null: false
    t.string "external_id"
    t.jsonb "external_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "reported_balance", precision: 25, scale: 10
    t.index ["currency_id"], name: "index_accounts_on_currency_id"
    t.index ["user_id"], name: "index_accounts_on_user_id"
    t.index ["wallet_id"], name: "index_accounts_on_wallet_id"
  end

  create_table "assets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "currency_id", null: false
    t.decimal "total_amount", precision: 25, scale: 10, default: "0.0", null: false
    t.decimal "total_reported_amount", precision: 25, scale: 10, default: "0.0", null: false
    t.decimal "invested_amount", precision: 25, scale: 10, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "currency_id"], name: "index_assets_on_user_id_and_currency_id", unique: true
    t.index ["user_id"], name: "index_assets_on_user_id"
  end

  create_table "countries", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.bigint "currency_id", null: false
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["currency_id"], name: "index_countries_on_currency_id"
  end

  create_table "coupons", force: :cascade do |t|
    t.bigint "owner_id"
    t.string "code", null: false
    t.string "type", null: false
    t.jsonb "rules"
    t.integer "usages", default: 0, null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_coupons_on_code", unique: true
    t.index ["owner_id"], name: "index_coupons_on_owner_id"
  end

  create_table "csv_imports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "wallet_id"
    t.string "file_file_name"
    t.string "file_content_type"
    t.integer "file_file_size"
    t.datetime "file_updated_at"
    t.text "initial_rows"
    t.jsonb "results"
    t.jsonb "options"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "mapping_id"
    t.string "state"
    t.string "error"
    t.index ["user_id"], name: "index_csv_imports_on_user_id"
  end

  create_table "currencies", force: :cascade do |t|
    t.string "symbol", null: false
    t.string "name", null: false
    t.boolean "fiat", default: false, null: false
    t.boolean "active", default: true, null: false
    t.integer "priority", default: 0, null: false
    t.string "icon_file_name"
    t.string "icon_content_type"
    t.integer "icon_file_size"
    t.datetime "icon_updated_at"
    t.datetime "synced_at"
    t.jsonb "external_data"
    t.string "cmc_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "added_at", null: false
    t.datetime "discontinued_at"
    t.string "crypto_compare_id"
    t.string "token_address"
    t.integer "platform_id"
    t.boolean "added_by_user", default: false, null: false
    t.integer "stablecoin_id"
    t.boolean "spam", default: false, null: false
    t.integer "rank"
    t.decimal "price"
    t.jsonb "market_data"
    t.string "coingecko_id"
    t.string "price_source"
    t.datetime "last_known_price_date"
    t.index ["active"], name: "index_currencies_on_active"
    t.index ["cmc_id"], name: "index_currencies_on_cmc_id"
    t.index ["coingecko_id"], name: "index_currencies_on_coingecko_id"
    t.index ["platform_id"], name: "index_currencies_on_platform_id"
    t.index ["priority", "rank", "symbol"], name: "index_currencies_on_priority_and_rank_and_symbol", order: { priority: :desc }
    t.index ["token_address"], name: "index_currencies_on_token_address"
  end

  create_table "entries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "transaction_id"
    t.bigint "account_id", null: false
    t.decimal "amount", precision: 25, scale: 10, null: false
    t.boolean "fee", default: false, null: false
    t.string "external_id"
    t.jsonb "external_data"
    t.datetime "date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "synced", default: false, null: false
    t.decimal "balance", precision: 25, scale: 10
    t.boolean "negative", default: false, null: false
    t.boolean "manual", default: false, null: false
    t.string "txhash"
    t.string "importer_tag"
    t.boolean "adjustment", default: false, null: false
    t.boolean "ignored", default: false, null: false
    t.index ["account_id", "external_id"], name: "index_entries_on_account_id_and_external_id"
    t.index ["account_id", "transaction_id"], name: "index_entries_on_account_id_and_transaction_id"
    t.index ["account_id"], name: "index_entries_on_account_id"
    t.index ["transaction_id"], name: "index_entries_on_transaction_id"
    t.index ["user_id"], name: "index_entries_on_user_id"
  end

  create_table "fingerprints", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "fp_type", null: false
    t.string "fp", null: false
    t.boolean "ignore", default: false, null: false
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "fp_type", "fp"], name: "index_fingerprints_on_user_id_and_fp_type_and_fp", unique: true
    t.index ["user_id"], name: "index_fingerprints_on_user_id"
  end

  create_table "investments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "transaction_id"
    t.bigint "account_id"
    t.bigint "currency_id", null: false
    t.decimal "amount", precision: 25, scale: 10, null: false
    t.decimal "value", precision: 25, scale: 10, null: false
    t.decimal "gain", precision: 25, scale: 10, default: "0.0", null: false
    t.datetime "date", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "extracted_amount", precision: 25, scale: 10, default: "0.0", null: false
    t.decimal "extracted_value", precision: 25, scale: 10, default: "0.0", null: false
    t.string "subtype"
    t.datetime "from_date"
    t.bigint "from_id"
    t.string "pool_name"
    t.boolean "long_term", default: false, null: false
    t.boolean "deposit", default: false, null: false
    t.jsonb "metadata"
    t.index ["account_id"], name: "index_investments_on_account_id"
    t.index ["currency_id"], name: "index_investments_on_currency_id"
    t.index ["from_id"], name: "index_investments_on_from_id"
    t.index ["transaction_id"], name: "index_investments_on_transaction_id"
    t.index ["user_id", "account_id"], name: "index_investments_on_user_id_and_account_id"
    t.index ["user_id", "amount", "extracted_amount", "currency_id", "date"], name: "deposits_index"
    t.index ["user_id", "currency_id"], name: "index_investments_on_user_id_and_currency_id"
    t.index ["user_id", "date"], name: "index_investments_on_user_id_and_date"
    t.index ["user_id", "transaction_id"], name: "index_investments_on_user_id_and_transaction_id"
    t.index ["user_id"], name: "index_investments_on_user_id"
  end

  create_table "job_statuses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "klass", null: false
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "args", default: "", null: false
    t.index ["user_id", "klass", "args"], name: "index_job_statuses_on_user_id_and_klass_and_args", unique: true
    t.index ["user_id"], name: "index_job_statuses_on_user_id"
  end

  create_table "payouts", force: :cascade do |t|
    t.bigint "user_id"
    t.decimal "amount", precision: 8, scale: 2, null: false
    t.string "description"
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_payouts_on_user_id"
  end

  create_table "perma_locks", force: :cascade do |t|
    t.string "name", null: false
    t.jsonb "metadata"
    t.datetime "stale_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_perma_locks_on_name", unique: true
  end

  create_table "plans", force: :cascade do |t|
    t.string "name", null: false
    t.integer "max_txns", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "price", null: false
  end

  create_table "rates", force: :cascade do |t|
    t.bigint "currency_id", null: false
    t.decimal "quoted_rate", precision: 25, scale: 10, null: false
    t.datetime "date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "hourly_rates"
    t.decimal "volume", default: "0.0", null: false
    t.string "source"
    t.index ["currency_id", "date"], name: "index_rates_on_currency_id_and_date", unique: true
    t.index ["currency_id"], name: "index_rates_on_currency_id"
  end

  create_table "reports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "type", null: false
    t.string "name", null: false
    t.datetime "from"
    t.datetime "to"
    t.datetime "generated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "file_file_name"
    t.string "file_content_type"
    t.integer "file_file_size"
    t.datetime "file_updated_at"
    t.string "format", null: false
    t.boolean "send_email", default: false, null: false
    t.integer "year"
    t.index ["user_id"], name: "index_reports_on_user_id"
  end

  create_table "snapshots", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.decimal "total_worth", precision: 25, scale: 10, default: "0.0", null: false
    t.decimal "invested", precision: 25, scale: 10, default: "0.0", null: false
    t.decimal "gains", precision: 25, scale: 10, default: "0.0", null: false
    t.jsonb "worths"
    t.datetime "date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "date"], name: "index_snapshots_on_user_id_and_date", unique: true
    t.index ["user_id", "id"], name: "index_snapshots_on_user_id_and_id"
    t.index ["user_id"], name: "index_snapshots_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "plan_id", null: false
    t.datetime "expires_at", null: false
    t.datetime "refunded_at"
    t.string "stripe_charge_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "max_txns", default: 0, null: false
    t.bigint "commission_coupon_id"
    t.bigint "discount_coupon_id"
    t.decimal "commission_total", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "discount_total", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "amount_paid", null: false
    t.string "notes"
    t.index ["commission_coupon_id"], name: "index_subscriptions_on_commission_coupon_id"
    t.index ["discount_coupon_id"], name: "index_subscriptions_on_discount_coupon_id"
    t.index ["plan_id"], name: "index_subscriptions_on_plan_id"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "symbol_aliases", force: :cascade do |t|
    t.bigint "currency_id", null: false
    t.string "symbol", null: false
    t.string "tag", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["currency_id"], name: "index_symbol_aliases_on_currency_id"
    t.index ["symbol", "tag"], name: "index_symbol_aliases_on_symbol_and_tag", unique: true
  end

  create_table "transactions", force: :cascade do |t|
    t.string "transaction_type", null: false
    t.bigint "user_id", null: false
    t.bigint "from_account_id"
    t.bigint "to_account_id"
    t.bigint "fee_account_id"
    t.bigint "from_currency_id"
    t.bigint "to_currency_id"
    t.bigint "fee_currency_id"
    t.decimal "from_amount", precision: 25, scale: 10, default: "0.0", null: false
    t.decimal "to_amount", precision: 25, scale: 10, default: "0.0", null: false
    t.decimal "fee_amount", precision: 25, scale: 10, default: "0.0", null: false
    t.decimal "net_value", precision: 25, scale: 10, default: "0.0", null: false
    t.decimal "fee_value", precision: 25, scale: 10, default: "0.0", null: false
    t.string "label"
    t.text "description"
    t.jsonb "cached_rates"
    t.string "txhash"
    t.datetime "date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "txsrc"
    t.string "txdest"
    t.string "importer_tag"
    t.boolean "negative_balances", default: false, null: false
    t.boolean "missing_rates", default: false, null: false
    t.decimal "net_worth_amount"
    t.bigint "net_worth_currency_id"
    t.decimal "fee_worth_amount"
    t.bigint "fee_worth_currency_id"
    t.boolean "margin"
    t.string "group_name"
    t.datetime "group_date"
    t.datetime "group_from"
    t.datetime "group_to"
    t.integer "group_count"
    t.decimal "from_cost_basis", precision: 25, scale: 10
    t.decimal "to_cost_basis", precision: 25, scale: 10
    t.decimal "gain", precision: 25, scale: 10
    t.string "from_source"
    t.string "to_source"
    t.boolean "reviewed_by_user", default: false, null: false
    t.integer "from_wallet_id"
    t.integer "to_wallet_id"
    t.decimal "missing_cost_basis", precision: 12, scale: 2
    t.integer "sort_index", default: 0, null: false
    t.boolean "ignored", default: false, null: false
    t.index ["fee_account_id"], name: "index_transactions_on_fee_account_id"
    t.index ["from_account_id", "to_account_id", "fee_account_id"], name: "account_transactions"
    t.index ["from_account_id"], name: "index_transactions_on_from_account_id"
    t.index ["from_wallet_id"], name: "index_transactions_on_from_wallet_id"
    t.index ["to_account_id"], name: "index_transactions_on_to_account_id"
    t.index ["to_wallet_id"], name: "index_transactions_on_to_wallet_id"
    t.index ["user_id", "fee_currency_id"], name: "index_transactions_on_user_id_and_fee_currency_id"
    t.index ["user_id", "from_currency_id"], name: "index_transactions_on_user_id_and_from_currency_id"
    t.index ["user_id", "id", "date"], name: "index_transactions_on_user_id_and_id_and_date"
    t.index ["user_id", "to_currency_id"], name: "index_transactions_on_user_id_and_to_currency_id"
    t.index ["user_id", "transaction_type", "from_account_id", "to_account_id", "txhash"], name: "index_transactions_on_user_id_type_txhash_etc"
  end

  create_table "user_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "message", null: false
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_logs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "avatar_file_name"
    t.string "avatar_content_type"
    t.integer "avatar_file_size"
    t.datetime "avatar_updated_at"
    t.bigint "base_currency_id", null: false
    t.bigint "display_currency_id", null: false
    t.string "password_digest"
    t.string "password_reset_token"
    t.string "api_token"
    t.datetime "last_seen_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cost_basis_method", default: "fifo", null: false
    t.bigint "country_id"
    t.jsonb "preferences"
    t.string "ip_address"
    t.string "via"
    t.string "auth_provider"
    t.string "auth_provider_id"
    t.bigint "discount_coupon_id"
    t.string "affiliate_paypal_email"
    t.boolean "affiliate_only", default: false, null: false
    t.string "utm_source"
    t.string "utm_medium"
    t.boolean "rebuild_scheduled", default: false, null: false
    t.integer "related_to_id"
    t.integer "related_by_id"
    t.datetime "fraud_date"
    t.boolean "blocked", default: false, null: false
    t.string "uuid", null: false
    t.string "jira_customer_id"
    t.index ["base_currency_id"], name: "index_users_on_base_currency_id"
    t.index ["country_id"], name: "index_users_on_country_id"
    t.index ["discount_coupon_id"], name: "index_users_on_discount_coupon_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["uuid"], name: "index_users_on_uuid", unique: true
  end

  create_table "wallet_services", force: :cascade do |t|
    t.string "name", null: false
    t.string "api_importer"
    t.string "icon_file_name"
    t.string "icon_content_type"
    t.integer "icon_file_size"
    t.datetime "icon_updated_at"
    t.boolean "api_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "api_beta", default: false, null: false
    t.boolean "shutdown", default: false, null: false
    t.integer "priority", default: 0, null: false
    t.string "integration_type", default: "other", null: false
    t.string "tag", null: false
  end

  create_table "wallets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "wallet_service_id"
    t.string "name", null: false
    t.datetime "synced_at"
    t.jsonb "api_options"
    t.jsonb "api_syncdata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "last_error"
    t.datetime "last_error_at"
    t.datetime "sync_started_at"
    t.boolean "auth_failed", default: false, null: false
    t.string "external_id"
    t.boolean "api_connected", default: false, null: false
    t.index ["user_id"], name: "index_wallets_on_user_id"
    t.index ["wallet_service_id"], name: "index_wallets_on_wallet_service_id"
  end

  add_foreign_key "accounts", "currencies"
  add_foreign_key "accounts", "users"
  add_foreign_key "accounts", "wallets"
  add_foreign_key "assets", "currencies"
  add_foreign_key "assets", "users"
  add_foreign_key "countries", "currencies"
  add_foreign_key "coupons", "users", column: "owner_id"
  add_foreign_key "csv_imports", "users"
  add_foreign_key "entries", "accounts"
  add_foreign_key "entries", "transactions"
  add_foreign_key "entries", "users"
  add_foreign_key "fingerprints", "users"
  add_foreign_key "investments", "accounts"
  add_foreign_key "investments", "currencies"
  add_foreign_key "investments", "investments", column: "from_id"
  add_foreign_key "investments", "transactions"
  add_foreign_key "investments", "users"
  add_foreign_key "job_statuses", "users"
  add_foreign_key "payouts", "users"
  add_foreign_key "rates", "currencies"
  add_foreign_key "reports", "users"
  add_foreign_key "snapshots", "users"
  add_foreign_key "subscriptions", "coupons", column: "commission_coupon_id"
  add_foreign_key "subscriptions", "coupons", column: "discount_coupon_id"
  add_foreign_key "subscriptions", "plans"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "symbol_aliases", "currencies"
  add_foreign_key "transactions", "accounts", column: "fee_account_id"
  add_foreign_key "transactions", "accounts", column: "from_account_id"
  add_foreign_key "transactions", "accounts", column: "to_account_id"
  add_foreign_key "transactions", "currencies", column: "fee_currency_id"
  add_foreign_key "transactions", "currencies", column: "fee_worth_currency_id"
  add_foreign_key "transactions", "currencies", column: "from_currency_id"
  add_foreign_key "transactions", "currencies", column: "net_worth_currency_id"
  add_foreign_key "transactions", "currencies", column: "to_currency_id"
  add_foreign_key "transactions", "users"
  add_foreign_key "user_logs", "users"
  add_foreign_key "users", "countries"
  add_foreign_key "users", "coupons", column: "discount_coupon_id"
  add_foreign_key "users", "currencies", column: "base_currency_id"
  add_foreign_key "users", "currencies", column: "display_currency_id"
  add_foreign_key "wallets", "users"
  add_foreign_key "wallets", "wallet_services"
end
