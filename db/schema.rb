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

ActiveRecord::Schema[8.0].define(version: 2026_02_28_030042) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ai_insights", force: :cascade do |t|
    t.string "insight_type"
    t.string "title", null: false
    t.text "content", null: false
    t.jsonb "related_comments", default: []
    t.float "confidence_score"
    t.string "ai_model"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_ai_insights_on_created_at"
    t.index ["insight_type"], name: "index_ai_insights_on_insight_type"
  end

  create_table "comment_tags", force: :cascade do |t|
    t.bigint "comment_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["comment_id", "tag_id"], name: "index_comment_tags_on_comment_id_and_tag_id", unique: true
    t.index ["comment_id"], name: "index_comment_tags_on_comment_id"
    t.index ["tag_id"], name: "index_comment_tags_on_tag_id"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "github_id", null: false
    t.bigint "pull_request_id", null: false
    t.text "body", null: false
    t.string "author_name"
    t.string "author_avatar"
    t.string "author_role"
    t.string "comment_type"
    t.string "path"
    t.integer "position"
    t.integer "line"
    t.boolean "ai_analyzed", default: false
    t.text "ai_summary"
    t.datetime "github_created_at"
    t.datetime "github_updated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_analyzed"], name: "index_comments_on_ai_analyzed"
    t.index ["author_name"], name: "index_comments_on_author_name"
    t.index ["github_id"], name: "index_comments_on_github_id", unique: true
    t.index ["pull_request_id"], name: "index_comments_on_pull_request_id"
  end

  create_table "pull_requests", force: :cascade do |t|
    t.bigint "github_id", null: false
    t.integer "number", null: false
    t.string "title", null: false
    t.text "body"
    t.string "state"
    t.string "author_name"
    t.string "author_avatar"
    t.string "repository_name"
    t.string "repository_url"
    t.integer "additions", default: 0
    t.integer "deletions", default: 0
    t.integer "changed_files_count", default: 0
    t.string "mergeable_state"
    t.boolean "draft", default: false
    t.datetime "github_created_at"
    t.datetime "github_updated_at"
    t.datetime "closed_at"
    t.datetime "merged_at"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["github_created_at"], name: "index_pull_requests_on_github_created_at"
    t.index ["github_id"], name: "index_pull_requests_on_github_id", unique: true
    t.index ["state"], name: "index_pull_requests_on_state"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.string "color", default: "#6B7280"
    t.text "description"
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  add_foreign_key "comment_tags", "comments"
  add_foreign_key "comment_tags", "tags"
  add_foreign_key "comments", "pull_requests"
end
