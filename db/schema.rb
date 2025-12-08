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

ActiveRecord::Schema[7.2].define(version: 2025_12_06_122207) do
  create_table "admin_users", force: :cascade do |t|
    t.string "email", null: false
    t.string "role", default: "billing_officer", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["role"], name: "index_admin_users_on_role"
  end

  create_table "billings", force: :cascade do |t|
    t.date "start_date"
    t.date "end_date"
    t.decimal "amount"
    t.date "due_date"
    t.string "status"
    t.integer "subscriber_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["subscriber_id"], name: "index_billings_on_subscriber_id"
  end

  create_table "file_uploads", force: :cascade do |t|
    t.integer "subscriber_id", null: false
    t.string "s3_key", null: false
    t.string "original_filename", null: false
    t.bigint "file_size"
    t.string "mime_type"
    t.string "etag"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["s3_key"], name: "index_file_uploads_on_s3_key"
    t.index ["subscriber_id", "created_at"], name: "index_file_uploads_on_subscriber_id_and_created_at"
    t.index ["subscriber_id"], name: "index_file_uploads_on_subscriber_id"
  end

  create_table "payments", force: :cascade do |t|
    t.date "payment_date"
    t.decimal "amount"
    t.string "payment_method"
    t.string "status"
    t.string "attachment"
    t.string "reference_number"
    t.integer "billing_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "receipt_filename"
    t.bigint "receipt_size"
    t.string "receipt_mime_type"
    t.datetime "receipt_uploaded_at"
    t.string "invoice_number"
    t.index ["billing_id"], name: "index_payments_on_billing_id"
    t.index ["payment_method"], name: "index_payments_on_payment_method"
    t.index ["receipt_uploaded_at"], name: "index_payments_on_receipt_uploaded_at"
  end

  create_table "subscribers", force: :cascade do |t|
    t.string "collector"
    t.string "zone"
    t.date "date_installed"
    t.string "last_name"
    t.string "first_name"
    t.string "phone_number"
    t.string "alternative_phone"
    t.string "serial_number"
    t.boolean "tvconnect"
    t.string "package"
    t.string "plan"
    t.integer "brate"
    t.string "mc_address"
    t.string "stb"
    t.string "cas"
    t.integer "package_speed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest"
    t.boolean "requires_password_change"
  end

  add_foreign_key "billings", "subscribers"
  add_foreign_key "file_uploads", "subscribers"
  add_foreign_key "payments", "billings"
end
