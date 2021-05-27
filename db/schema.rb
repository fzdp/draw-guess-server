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

ActiveRecord::Schema.define(version: 2021_05_23_005622) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "games", force: :cascade do |t|
    t.string "answer", null: false
    t.bigint "room_id"
    t.integer "painter_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.jsonb "operations"
    t.integer "winner_ids", array: true
    t.integer "user_ids", array: true
    t.string "answer_hint", default: ""
    t.integer "canvas_height", default: 0
    t.integer "canvas_width", default: 0
    t.string "artwork_id"
    t.index ["painter_id"], name: "index_games_on_painter_id"
    t.index ["room_id"], name: "index_games_on_room_id"
    t.index ["user_ids"], name: "index_games_on_user_ids", using: :gin
  end

  create_table "messages", force: :cascade do |t|
    t.string "content"
    t.bigint "user_id"
    t.bigint "room_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["room_id"], name: "index_messages_on_room_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.string "name"
    t.boolean "is_public", default: false
    t.integer "creator_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "aasm_state"
    t.integer "tag_ids", array: true
    t.string "password"
    t.index ["tag_ids"], name: "index_rooms_on_tag_ids", using: :gin
  end

  create_table "score_records", force: :cascade do |t|
    t.integer "score"
    t.integer "total_score"
    t.bigint "user_id"
    t.bigint "game_id"
    t.bigint "room_id"
    t.string "reason", default: ""
    t.float "time_taken", default: 0.0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["game_id"], name: "index_score_records_on_game_id"
    t.index ["reason"], name: "index_score_records_on_reason"
    t.index ["room_id"], name: "index_score_records_on_room_id"
    t.index ["time_taken"], name: "index_score_records_on_time_taken"
    t.index ["user_id"], name: "index_score_records_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.bigint "room_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "status"
    t.string "username"
    t.string "avatar_id"
    t.integer "score", default: 0
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["room_id"], name: "index_users_on_room_id"
    t.index ["score"], name: "index_users_on_score"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "word_items", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "word_tag_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name", "word_tag_id"], name: "index_word_items_on_name_and_word_tag_id", unique: true
    t.index ["word_tag_id"], name: "index_word_items_on_word_tag_id"
  end

  create_table "word_tags", force: :cascade do |t|
    t.string "name", null: false
    t.integer "seq", limit: 2, default: 0
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  add_foreign_key "games", "rooms"
  add_foreign_key "messages", "rooms"
  add_foreign_key "messages", "users"
  add_foreign_key "score_records", "users"
  add_foreign_key "users", "rooms"
end
