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

ActiveRecord::Schema[7.2].define(version: 2025_11_02_044904) do
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
end
