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

ActiveRecord::Schema[8.1].define(version: 2026_09_10_041400) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "channels", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "last_synced_at"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "uploads_playlist_id"
    t.string "youtube_channel_id", null: false
    t.string "youtube_url"
    t.index ["youtube_channel_id"], name: "index_channels_on_youtube_channel_id", unique: true
  end

  create_table "competitions", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.string "api_url"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.bigint "sport_id", null: false
    t.datetime "updated_at", null: false
    t.string "video_naming_convention"
    t.index ["slug"], name: "index_competitions_on_slug", unique: true
    t.index ["sport_id"], name: "index_competitions_on_sport_id"
  end

  create_table "sports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_sports_on_slug", unique: true
  end

  create_table "videos", force: :cascade do |t|
    t.bigint "channel_id", null: false
    t.bigint "competition_id"
    t.datetime "created_at", null: false
    t.integer "duration_seconds"
    t.boolean "embeddable", default: true, null: false
    t.boolean "is_highlight", default: false, null: false
    t.string "original_title", null: false
    t.datetime "published_at", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.boolean "region_restricted", default: false, null: false
    t.string "safe_title"
    t.datetime "updated_at", null: false
    t.string "youtube_video_id", null: false
    t.index ["channel_id"], name: "index_videos_on_channel_id"
    t.index ["competition_id"], name: "index_videos_on_competition_id"
    t.index ["is_highlight", "published_at"], name: "index_videos_on_is_highlight_and_published_at"
    t.index ["youtube_video_id"], name: "index_videos_on_youtube_video_id", unique: true
  end

  add_foreign_key "competitions", "sports"
  add_foreign_key "videos", "channels"
  add_foreign_key "videos", "competitions"
end
