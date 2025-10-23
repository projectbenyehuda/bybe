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

ActiveRecord::Schema[8.0].define(version: 2025_10_21_231345) do
  create_table "aboutnesses", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "work_id"
    t.integer "user_id"
    t.integer "status"
    t.integer "wikidata_qid"
    t.integer "aboutable_id"
    t.string "aboutable_type"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "wikidata_label"
    t.index ["aboutable_type", "aboutable_id"], name: "index_aboutnesses_on_aboutable_type_and_aboutable_id"
    t.index ["user_id"], name: "index_aboutnesses_on_user_id"
    t.index ["wikidata_qid"], name: "index_aboutnesses_on_wikidata_qid"
    t.index ["work_id"], name: "index_aboutnesses_on_work_id"
  end

  create_table "active_storage_attachments", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", precision: nil, null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", precision: nil, null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ahoy_events", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.bigint "visit_id"
    t.bigint "user_id"
    t.string "name"
    t.json "properties"
    t.datetime "time", precision: nil
    t.virtual "item_id", type: :integer, as: "json_unquote(json_extract(`properties`,_utf8mb4'$.id'))"
    t.virtual "item_type", type: :string, limit: 50, as: "json_unquote(json_extract(`properties`,_utf8mb4'$.type'))"
    t.index ["item_id", "item_type", "name"], name: "index_ahoy_events_on_item_id_and_item_type_and_name"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "visit_token"
    t.string "visitor_token"
    t.bigint "user_id"
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.string "referring_domain"
    t.text "landing_page"
    t.string "browser"
    t.string "os"
    t.string "device_type"
    t.string "country"
    t.string "region"
    t.string "city"
    t.float "latitude"
    t.float "longitude"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_term"
    t.string "utm_content"
    t.string "utm_campaign"
    t.string "app_version"
    t.string "os_version"
    t.string "platform"
    t.datetime "started_at", precision: nil
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
  end

  create_table "anthologies", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "title"
    t.integer "user_id"
    t.integer "access"
    t.integer "cached_page_count"
    t.text "sequence", size: :medium
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "impressions_count", default: 0
    t.index ["user_id"], name: "index_anthologies_on_user_id"
  end

  create_table "anthology_texts", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "title"
    t.text "body", size: :medium
    t.bigint "anthology_id"
    t.integer "manifestation_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "cached_page_count"
    t.index ["anthology_id"], name: "index_anthology_texts_on_anthology_id"
    t.index ["manifestation_id"], name: "index_anthology_texts_on_manifestation_id"
  end

  create_table "api_keys", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "email"
    t.string "description"
    t.string "key"
    t.integer "status"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["email"], name: "index_api_keys_on_email", unique: true
    t.index ["key"], name: "index_api_keys_on_key", unique: true
  end

  create_table "authorities", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "name"
    t.string "other_designation", limit: 1024
    t.string "country"
    t.text "comment", size: :medium
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "viaf_id"
    t.string "nli_id"
    t.integer "toc_id"
    t.text "wikipedia_snippet", size: :medium
    t.string "wikipedia_url", limit: 1024
    t.string "profile_image_file_name"
    t.string "profile_image_content_type"
    t.integer "profile_image_file_size"
    t.datetime "profile_image_updated_at", precision: nil
    t.integer "impressions_count"
    t.string "blog_category_url"
    t.boolean "bib_done"
    t.string "sort_name"
    t.integer "status"
    t.datetime "published_at", precision: nil
    t.integer "intellectual_property", null: false
    t.string "wikidata_uri"
    t.integer "person_id"
    t.integer "corporate_body_id"
    t.integer "uncollected_works_collection_id"
    t.integer "legacy_toc_id"
    t.text "legacy_credits"
    t.text "cached_credits"
    t.index ["corporate_body_id"], name: "index_authorities_on_corporate_body_id", unique: true
    t.index ["impressions_count"], name: "index_authorities_on_impressions_count"
    t.index ["intellectual_property"], name: "index_authorities_on_intellectual_property"
    t.index ["name"], name: "index_authorities_on_name"
    t.index ["person_id"], name: "index_authorities_on_person_id", unique: true
    t.index ["sort_name"], name: "index_authorities_on_sort_name"
    t.index ["status", "published_at"], name: "index_authorities_on_status_and_published_at"
    t.index ["toc_id"], name: "people_toc_id_fk"
    t.index ["uncollected_works_collection_id"], name: "index_authorities_on_uncollected_works_collection_id", unique: true
  end

  create_table "base_user_preferences", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "name", null: false
    t.string "value"
    t.bigint "base_user_id", null: false
    t.index ["base_user_id"], name: "index_base_user_preferences_on_base_user_id"
  end

  create_table "base_users", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "user_id"
    t.string "session_id"
    t.index ["session_id"], name: "index_base_users_on_session_id", unique: true
    t.index ["user_id"], name: "index_base_users_on_user_id", unique: true
  end

  create_table "bib_sources", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "title"
    t.integer "source_type"
    t.string "url"
    t.integer "port"
    t.string "api_key"
    t.text "comments"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "status"
    t.string "institution"
    t.string "item_pattern", limit: 2048
    t.string "vid"
    t.string "scope"
  end

  create_table "blazer_audits", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "query_id"
    t.text "statement"
    t.string "data_source"
    t.datetime "created_at", precision: nil
    t.index ["query_id"], name: "index_blazer_audits_on_query_id"
    t.index ["user_id"], name: "index_blazer_audits_on_user_id"
  end

  create_table "blazer_checks", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.bigint "creator_id"
    t.bigint "query_id"
    t.string "state"
    t.string "schedule"
    t.text "emails"
    t.text "slack_channels"
    t.string "check_type"
    t.text "message"
    t.datetime "last_run_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["creator_id"], name: "index_blazer_checks_on_creator_id"
    t.index ["query_id"], name: "index_blazer_checks_on_query_id"
  end

  create_table "blazer_dashboard_queries", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.bigint "dashboard_id"
    t.bigint "query_id"
    t.integer "position"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["dashboard_id"], name: "index_blazer_dashboard_queries_on_dashboard_id"
    t.index ["query_id"], name: "index_blazer_dashboard_queries_on_query_id"
  end

  create_table "blazer_dashboards", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.bigint "creator_id"
    t.string "name"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["creator_id"], name: "index_blazer_dashboards_on_creator_id"
  end

  create_table "blazer_queries", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.bigint "creator_id"
    t.string "name"
    t.text "description"
    t.text "statement"
    t.string "data_source"
    t.string "status"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["creator_id"], name: "index_blazer_queries_on_creator_id"
  end

  create_table "bookmarks", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "manifestation_id"
    t.string "bookmark_p"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "base_user_id", null: false
    t.index ["base_user_id", "manifestation_id"], name: "index_bookmarks_on_base_user_id_and_manifestation_id", unique: true
    t.index ["base_user_id"], name: "index_bookmarks_on_base_user_id"
    t.index ["manifestation_id"], name: "index_bookmarks_on_manifestation_id"
  end

  create_table "collection_items", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "collection_id"
    t.string "alt_title", limit: 2048
    t.text "context"
    t.integer "seqno"
    t.string "item_type"
    t.bigint "item_id"
    t.text "markdown"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "paratext"
    t.index ["collection_id"], name: "index_collection_items_on_collection_id"
    t.index ["item_type", "item_id"], name: "index_collection_items_on_item"
  end

  create_table "collections", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "title", limit: 1024
    t.string "sort_title"
    t.string "subtitle"
    t.string "issn"
    t.integer "collection_type"
    t.string "inception"
    t.integer "inception_year"
    t.integer "publication_id"
    t.integer "toc_id"
    t.integer "toc_strategy"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "publisher_line", limit: 2048
    t.string "pub_year"
    t.integer "normalized_pub_year"
    t.text "credits"
    t.text "cached_credits"
    t.string "alternate_titles", limit: 1024
    t.boolean "suppress_download_and_print", default: false, null: false
    t.integer "impressions_count", default: 0
    t.index ["inception_year"], name: "index_collections_on_inception_year"
    t.index ["publication_id"], name: "index_collections_on_publication_id"
    t.index ["sort_title"], name: "index_collections_on_sort_title"
    t.index ["toc_id"], name: "index_collections_on_toc_id"
  end

  create_table "corporate_bodies", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "inception"
    t.integer "inception_year"
    t.string "dissolution"
    t.integer "dissolution_year"
    t.string "location"
  end

  create_table "delayed_jobs", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at", precision: nil
    t.datetime "locked_at", precision: nil
    t.datetime "failed_at", precision: nil
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "dictionary_aliases", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.bigint "dictionary_entry_id"
    t.string "alias"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["dictionary_entry_id"], name: "index_dictionary_aliases_on_dictionary_entry_id"
  end

  create_table "dictionary_entries", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "manifestation_id"
    t.integer "sequential_number"
    t.string "defhead"
    t.text "deftext", size: :medium
    t.integer "source_def_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "sort_defhead"
    t.index ["defhead"], name: "index_dictionary_entries_on_defhead"
    t.index ["manifestation_id", "sequential_number"], name: "manif_and_seqno_index"
    t.index ["manifestation_id"], name: "index_dictionary_entries_on_manifestation_id"
    t.index ["sequential_number"], name: "index_dictionary_entries_on_sequential_number"
    t.index ["sort_defhead"], name: "index_dictionary_entries_on_sort_defhead"
    t.index ["source_def_id"], name: "index_dictionary_entries_on_source_def_id"
  end

  create_table "dictionary_links", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.bigint "from_entry_id"
    t.bigint "to_entry_id"
    t.integer "linktype"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["from_entry_id"], name: "index_dictionary_links_on_from_entry_id"
    t.index ["to_entry_id"], name: "index_dictionary_links_on_to_entry_id"
  end

  create_table "downloadables", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "object_type"
    t.bigint "object_id"
    t.integer "doctype"
    t.integer "status"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["object_type", "object_id"], name: "index_downloadables_on_object_type_and_object_id"
  end

  create_table "expressions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "title"
    t.string "form"
    t.string "date"
    t.string "language"
    t.text "comment", size: :medium
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.date "copyright_expiration"
    t.boolean "translation"
    t.string "source_edition"
    t.integer "period"
    t.string "normalized_pub_date"
    t.string "normalized_creation_date"
    t.integer "work_id", null: false
    t.integer "intellectual_property", null: false
    t.index ["intellectual_property"], name: "index_expressions_on_intellectual_property"
    t.index ["normalized_creation_date"], name: "index_expressions_on_normalized_creation_date"
    t.index ["normalized_pub_date"], name: "index_expressions_on_normalized_pub_date"
    t.index ["period"], name: "index_expressions_on_period"
    t.index ["work_id"], name: "index_expressions_on_work_id"
  end

  create_table "external_links", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "url", limit: 2048
    t.integer "linktype"
    t.integer "status"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "description"
    t.integer "linkable_id", null: false
    t.string "linkable_type", null: false
    t.index ["linkable_type", "linkable_id"], name: "index_external_links_on_linkable_type_and_linkable_id"
  end

  create_table "featured_author_features", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.datetime "fromdate", precision: nil
    t.datetime "todate", precision: nil
    t.integer "featured_author_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["featured_author_id"], name: "index_featured_author_features_on_featured_author_id"
  end

  create_table "featured_authors", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "title"
    t.integer "user_id"
    t.integer "person_id"
    t.text "body"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["person_id"], name: "index_featured_authors_on_person_id"
    t.index ["user_id"], name: "index_featured_authors_on_user_id"
  end

  create_table "featured_content_features", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "featured_content_id"
    t.datetime "fromdate", precision: nil
    t.datetime "todate", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["featured_content_id"], name: "index_featured_content_features_on_featured_content_id"
  end

  create_table "featured_contents", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "title"
    t.integer "manifestation_id"
    t.integer "authority_id"
    t.text "body"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "external_link"
    t.integer "user_id"
    t.index ["authority_id"], name: "index_featured_contents_on_authority_id"
    t.index ["manifestation_id"], name: "index_featured_contents_on_manifestation_id"
    t.index ["user_id"], name: "index_featured_contents_on_user_id"
  end

  create_table "holdings", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "publication_id"
    t.string "source_id", limit: 1024
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "status"
    t.string "scan_url", limit: 2048
    t.integer "bib_source_id"
    t.string "location"
    t.index ["bib_source_id"], name: "index_holdings_on_bib_source_id"
    t.index ["publication_id"], name: "index_holdings_on_publication_id"
  end

  create_table "html_dirs", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "path"
    t.string "author"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "need_resequence"
    t.boolean "public_domain"
    t.integer "person_id"
  end

  create_table "html_files", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "path"
    t.string "url"
    t.string "status"
    t.string "problem"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.boolean "tables"
    t.boolean "footnotes"
    t.boolean "images"
    t.string "nikkud"
    t.boolean "line_numbers"
    t.string "indentation"
    t.string "headings"
    t.string "orig_mtime"
    t.string "orig_ctime"
    t.boolean "stripped_nikkud"
    t.string "orig_lang"
    t.string "year_published"
    t.string "orig_year_published"
    t.integer "seqno"
    t.string "orig_author"
    t.string "orig_author_url"
    t.integer "author_id"
    t.string "genre"
    t.boolean "paras_condensed", default: false
    t.integer "translator_id"
    t.integer "assignee_id"
    t.text "comments"
    t.string "title"
    t.string "doc_file_name"
    t.string "doc_content_type"
    t.integer "doc_file_size"
    t.datetime "doc_updated_at", precision: nil
    t.text "markdown", size: :long
    t.string "publisher"
    t.string "pub_link"
    t.string "pub_link_text"
    t.index ["assignee_id"], name: "index_html_files_on_assignee_id"
    t.index ["path"], name: "index_html_files_on_path"
    t.index ["status"], name: "index_html_files_on_status"
    t.index ["url"], name: "index_html_files_on_url"
  end

  create_table "html_files_manifestations", id: false, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "html_file_id"
    t.integer "manifestation_id"
    t.index ["html_file_id"], name: "index_html_files_manifestations_on_html_file_id"
    t.index ["manifestation_id"], name: "index_html_files_manifestations_on_manifestation_id"
  end

  create_table "ingestibles", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "title"
    t.integer "status"
    t.integer "scenario"
    t.text "default_authorities"
    t.text "metadata"
    t.text "comments"
    t.text "markdown", size: :long
    t.integer "user_id"
    t.text "problem", size: :medium
    t.string "orig_lang"
    t.string "year_published"
    t.string "genre"
    t.string "publisher"
    t.string "pub_link", limit: 2048
    t.string "pub_link_text", limit: 1024
    t.boolean "attach_photos", default: false, null: false
    t.boolean "no_volume", default: false, null: false
    t.text "toc_buffer"
    t.integer "volume_id"
    t.text "works_buffer", size: :long
    t.datetime "markdown_updated_at", precision: nil
    t.datetime "works_buffer_updated_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "locked_by_user_id"
    t.timestamp "locked_at"
    t.string "prospective_volume_id"
    t.string "prospective_volume_title"
    t.integer "periodical_id"
    t.string "intellectual_property"
    t.text "ingested_changes"
    t.text "credits"
    t.string "originating_task"
    t.integer "last_editor_id"
    t.text "collection_authorities"
    t.index ["last_editor_id"], name: "index_ingestibles_on_last_editor_id"
    t.index ["locked_by_user_id"], name: "index_ingestibles_on_locked_by_user_id"
    t.index ["originating_task"], name: "index_ingestibles_on_originating_task"
    t.index ["status"], name: "index_ingestibles_on_status"
    t.index ["title"], name: "index_ingestibles_on_title"
    t.index ["user_id"], name: "index_ingestibles_on_user_id"
    t.index ["volume_id"], name: "index_ingestibles_on_volume_id"
  end

  create_table "involved_authorities", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "authority_id", null: false
    t.integer "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "item_type", null: false
    t.integer "item_id", null: false
    t.index ["authority_id", "item_id", "item_type", "role"], name: "index_involved_authority_uniq", unique: true
    t.index ["authority_id"], name: "index_involved_authorities_on_authority_id"
    t.index ["item_type", "item_id"], name: "index_involved_authorities_on_item"
  end

  create_table "legacy_recommendations", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "from"
    t.string "about"
    t.string "what"
    t.boolean "subscribe"
    t.string "status"
    t.integer "resolved_by"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "html_file_id"
    t.integer "recommended_by"
    t.integer "manifestation_id"
  end

  create_table "list_items", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "user_id"
    t.string "listkey"
    t.integer "item_id"
    t.string "item_type"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "extra"
    t.index ["item_type", "item_id"], name: "index_list_items_on_item_type_and_item_id"
    t.index ["listkey", "item_id"], name: "index_list_items_on_listkey_and_item_id"
    t.index ["listkey", "updated_at"], name: "index_list_items_on_listkey_and_updated_at"
    t.index ["listkey", "user_id", "item_id"], name: "index_list_items_on_listkey_and_user_id_and_item_id"
    t.index ["listkey"], name: "index_list_items_on_listkey"
    t.index ["user_id"], name: "index_list_items_on_user_id"
  end

  create_table "manifestations", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "title"
    t.string "responsibility_statement"
    t.string "edition"
    t.string "identifier"
    t.string "medium"
    t.string "publisher"
    t.string "publication_place"
    t.string "publication_date"
    t.string "series_statement"
    t.text "comment", size: :medium
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "markdown", size: :medium
    t.text "cached_people"
    t.integer "impressions_count"
    t.text "cached_heading_lines"
    t.boolean "conversion_verified"
    t.integer "conv_counter"
    t.integer "status"
    t.string "sort_title"
    t.boolean "sefaria_linker"
    t.integer "expression_id", null: false
    t.string "alternate_titles", limit: 512
    t.text "credits"
    t.boolean "exclude_from_index", default: false, null: false
    t.index ["conv_counter"], name: "index_manifestations_on_conv_counter"
    t.index ["created_at"], name: "index_manifestations_on_created_at"
    t.index ["expression_id"], name: "index_manifestations_on_expression_id"
    t.index ["impressions_count"], name: "index_manifestations_on_impressions_count"
    t.index ["sort_title"], name: "index_manifestations_on_sort_title"
    t.index ["status", "sort_title"], name: "index_manifestations_on_status_and_sort_title"
    t.index ["status"], name: "index_manifestations_on_status"
    t.index ["updated_at"], name: "index_manifestations_on_updated_at"
  end

  create_table "news_items", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "itemtype"
    t.string "title"
    t.boolean "pinned"
    t.datetime "relevance", precision: nil
    t.string "body"
    t.string "url"
    t.boolean "double"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "thumbnail_url"
    t.index ["relevance"], name: "index_news_items_on_relevance"
  end

  create_table "people", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "period"
    t.string "birthdate"
    t.string "deathdate"
    t.integer "gender"
  end

  create_table "periods", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "name"
    t.text "comments", size: :medium
    t.string "wikipedia_url"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "proofs", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "from"
    t.string "about"
    t.text "what", size: :medium
    t.boolean "subscribe"
    t.string "status"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "resolved_by"
    t.text "highlight", size: :medium
    t.integer "reported_by"
    t.string "item_type", null: false
    t.integer "item_id", null: false
    t.index ["item_id", "item_type", "status"], name: "index_proofs_on_item_id_and_item_type_and_status"
    t.index ["item_type"], name: "index_proofs_on_item_type"
    t.index ["resolved_by"], name: "proofs_resolved_by_fk"
    t.index ["status", "created_at"], name: "index_proofs_on_status_and_created_at"
  end

  create_table "publications", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "title", limit: 1024
    t.string "publisher_line"
    t.string "author_line", limit: 1024
    t.text "notes"
    t.string "source_id", limit: 1024
    t.integer "authority_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "status"
    t.string "pub_year"
    t.string "language"
    t.integer "bib_source_id"
    t.integer "task_id"
    t.index ["authority_id"], name: "index_publications_on_authority_id"
    t.index ["bib_source_id"], name: "index_publications_on_bib_source_id"
    t.index ["task_id"], name: "index_publications_on_task_id"
  end

  create_table "reading_lists", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "title"
    t.integer "user_id"
    t.integer "access"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["user_id"], name: "index_reading_lists_on_user_id"
  end

  create_table "recommendations", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.text "body"
    t.integer "user_id"
    t.integer "approved_by"
    t.integer "status"
    t.integer "manifestation_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["approved_by"], name: "recommendations_approved_by_fk"
    t.index ["manifestation_id", "status"], name: "index_recommendations_on_manifestation_id_and_status"
    t.index ["manifestation_id"], name: "index_recommendations_on_manifestation_id"
    t.index ["user_id"], name: "index_recommendations_on_user_id"
  end

  create_table "sessions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data", size: :medium
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["session_id"], name: "index_sessions_on_session_id"
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "sitenotices", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.text "body"
    t.datetime "fromdate", precision: nil
    t.datetime "todate", precision: nil
    t.integer "status"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["fromdate"], name: "index_sitenotices_on_fromdate"
    t.index ["status"], name: "index_sitenotices_on_status"
    t.index ["todate"], name: "index_sitenotices_on_todate"
  end

  create_table "static_pages", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "tag"
    t.string "title"
    t.text "body", size: :medium
    t.integer "status"
    t.integer "mode"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "ltr"
  end

  create_table "tag_names", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "tag_id"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tag_names_on_name", unique: true
    t.index ["tag_id"], name: "index_tag_names_on_tag_id"
  end

  create_table "taggings", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "tag_id"
    t.integer "taggable_id"
    t.integer "status"
    t.integer "suggested_by"
    t.integer "approved_by"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "taggable_type"
    t.index ["approved_by"], name: "taggings_approved_by_fk"
    t.index ["suggested_by"], name: "taggings_suggested_by_fk"
    t.index ["tag_id"], name: "taggings_tag_id_fk"
    t.index ["taggable_id", "taggable_type"], name: "index_taggings_on_taggable_id_and_taggable_type"
  end

  create_table "tags", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "name"
    t.integer "status"
    t.integer "created_by"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "approver_id"
    t.integer "taggings_count"
    t.string "wikidata_qid"
    t.index ["approver_id"], name: "index_tags_on_approver_id"
    t.index ["created_by"], name: "tags_created_by_fk"
    t.index ["status", "name"], name: "index_tags_on_status_and_name", unique: true
    t.index ["wikidata_qid"], name: "index_tags_on_wikidata_qid"
  end

  create_table "tocs", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.text "toc", size: :medium
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "credit_section"
    t.integer "status"
    t.text "cached_toc", size: :medium
  end

  create_table "user_blocks", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "user_id"
    t.string "context"
    t.datetime "expires_at", precision: nil
    t.integer "blocker_id"
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "context_item_type"
    t.bigint "context_item_id"
    t.index ["context"], name: "index_user_blocks_on_context"
    t.index ["context_item_type", "context_item_id"], name: "index_user_blocks_on_context_item"
    t.index ["user_id"], name: "index_user_blocks_on_user_id"
  end

  create_table "users", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "provider"
    t.string "uid"
    t.string "oauth_token"
    t.datetime "oauth_expires_at", precision: nil
    t.boolean "admin"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "editor"
    t.string "avatar_file_name"
    t.string "avatar_content_type"
    t.integer "avatar_file_size"
    t.datetime "avatar_updated_at", precision: nil
    t.string "tasks_api_key"
    t.boolean "crowdsourcer"
    t.date "warned_on"
  end

  create_table "versions", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "item_type", null: false
    t.integer "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object", size: :long
    t.datetime "created_at", precision: nil
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "volunteer_profile_features", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "volunteer_profile_id"
    t.datetime "fromdate", precision: nil
    t.datetime "todate", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["volunteer_profile_id"], name: "index_volunteer_profile_features_on_volunteer_profile_id"
  end

  create_table "volunteer_profiles", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "name"
    t.text "bio"
    t.text "about"
    t.string "profile_image_file_name"
    t.string "profile_image_content_type"
    t.integer "profile_image_file_size"
    t.datetime "profile_image_updated_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "work_likes", id: false, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "manifestation_id", null: false
    t.integer "user_id", null: false
    t.index ["manifestation_id", "user_id"], name: "index_work_likes_on_manifestation_id_and_user_id"
    t.index ["user_id", "manifestation_id"], name: "index_work_likes_on_user_id_and_manifestation_id"
  end

  create_table "works", id: :integer, charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.string "title"
    t.string "form"
    t.string "date"
    t.text "comment", size: :medium
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "genre"
    t.string "orig_lang"
    t.string "origlang_title"
    t.string "normalized_pub_date"
    t.string "normalized_creation_date"
    t.boolean "primary", null: false
    t.index ["normalized_creation_date"], name: "index_works_on_normalized_creation_date"
    t.index ["normalized_pub_date"], name: "index_works_on_normalized_pub_date"
  end

  create_table "year_totals", charset: "utf8mb4", collation: "utf8mb4_bin", force: :cascade do |t|
    t.integer "total"
    t.integer "year"
    t.string "item_type"
    t.bigint "item_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "event"
    t.index ["item_id", "item_type", "year", "event"], name: "index_year_totals_on_item_id_and_item_type_and_year_and_event", unique: true
    t.index ["item_type", "item_id"], name: "index_year_totals_on_item_type_and_item_id"
  end

  add_foreign_key "aboutnesses", "users"
  add_foreign_key "aboutnesses", "works"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "anthologies", "users"
  add_foreign_key "anthology_texts", "anthologies"
  add_foreign_key "anthology_texts", "manifestations"
  add_foreign_key "authorities", "collections", column: "uncollected_works_collection_id"
  add_foreign_key "authorities", "corporate_bodies"
  add_foreign_key "authorities", "people"
  add_foreign_key "authorities", "tocs", name: "people_toc_id_fk"
  add_foreign_key "base_user_preferences", "base_users"
  add_foreign_key "base_users", "users"
  add_foreign_key "bookmarks", "base_users"
  add_foreign_key "bookmarks", "manifestations"
  add_foreign_key "collection_items", "collections"
  add_foreign_key "collections", "publications"
  add_foreign_key "collections", "tocs"
  add_foreign_key "dictionary_aliases", "dictionary_entries"
  add_foreign_key "dictionary_entries", "manifestations"
  add_foreign_key "dictionary_links", "dictionary_entries", column: "from_entry_id"
  add_foreign_key "dictionary_links", "dictionary_entries", column: "to_entry_id"
  add_foreign_key "expressions", "works"
  add_foreign_key "featured_author_features", "featured_authors"
  add_foreign_key "featured_authors", "people"
  add_foreign_key "featured_authors", "users"
  add_foreign_key "featured_content_features", "featured_contents"
  add_foreign_key "featured_contents", "authorities"
  add_foreign_key "featured_contents", "manifestations"
  add_foreign_key "featured_contents", "users"
  add_foreign_key "holdings", "bib_sources"
  add_foreign_key "holdings", "publications"
  add_foreign_key "ingestibles", "collections", column: "volume_id"
  add_foreign_key "ingestibles", "users", column: "last_editor_id"
  add_foreign_key "ingestibles", "users", column: "locked_by_user_id"
  add_foreign_key "involved_authorities", "authorities"
  add_foreign_key "list_items", "users"
  add_foreign_key "manifestations", "expressions"
  add_foreign_key "proofs", "users", column: "resolved_by", name: "proofs_resolved_by_fk"
  add_foreign_key "publications", "authorities"
  add_foreign_key "publications", "bib_sources"
  add_foreign_key "reading_lists", "users"
  add_foreign_key "recommendations", "manifestations"
  add_foreign_key "recommendations", "users"
  add_foreign_key "recommendations", "users", column: "approved_by", name: "recommendations_approved_by_fk"
  add_foreign_key "tag_names", "tags"
  add_foreign_key "taggings", "tags", name: "taggings_tag_id_fk"
  add_foreign_key "taggings", "users", column: "approved_by", name: "taggings_approved_by_fk"
  add_foreign_key "taggings", "users", column: "suggested_by", name: "taggings_suggested_by_fk"
  add_foreign_key "tags", "users", column: "approver_id"
  add_foreign_key "tags", "users", column: "created_by", name: "tags_created_by_fk"
  add_foreign_key "user_blocks", "users"
  add_foreign_key "volunteer_profile_features", "volunteer_profiles"
  add_foreign_key "work_likes", "manifestations", name: "work_likes_manifestation_id_fk"
  add_foreign_key "work_likes", "users", name: "work_likes_user_id_fk"
end
