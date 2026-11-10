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

ActiveRecord::Schema[8.1].define(version: 2026_11_10_100003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "comments", force: :cascade do |t|
    t.text "body", null: false
    t.bigint "user_id", null: false
    t.bigint "submission_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "parent_id"
    t.integer "points", default: 0, null: false
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["submission_id"], name: "index_comments_on_submission_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "favorites", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "favoritable_type", null: false
    t.bigint "favoritable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["favoritable_type", "favoritable_id"], name: "index_favorites_on_favoritable"
    t.index ["user_id", "favoritable_type", "favoritable_id"], name: "index_favorites_on_user_and_favoritable", unique: true
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "hides", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "submission_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["submission_id"], name: "index_hides_on_submission_id"
    t.index ["user_id", "submission_id"], name: "index_hides_on_user_id_and_submission_id", unique: true
    t.index ["user_id"], name: "index_hides_on_user_id"
  end

  create_table "submissions", force: :cascade do |t|
    t.string "title"
    t.string "url"
    t.text "text"
    t.string "submission_type", default: "url", null: false
    t.integer "points", default: 0, null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "comments_count", default: 0, null: false
    t.index ["user_id"], name: "index_submissions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "provider"
    t.string "uid"
    t.string "username"
    t.string "email"
    t.text "about"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  create_table "votes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "votable_type", null: false
    t.bigint "votable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "votable_type", "votable_id"], name: "index_votes_on_user_and_votable", unique: true
    t.index ["user_id"], name: "index_votes_on_user_id"
    t.index ["votable_type", "votable_id"], name: "index_votes_on_votable"
  end

  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "submissions"
  add_foreign_key "comments", "users"
  add_foreign_key "favorites", "users"
  add_foreign_key "hides", "submissions"
  add_foreign_key "hides", "users"
  add_foreign_key "submissions", "users"
  add_foreign_key "votes", "users"
end
