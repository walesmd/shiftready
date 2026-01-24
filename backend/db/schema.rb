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

ActiveRecord::Schema[8.1].define(version: 2026_01_24_154203) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "block_lists", force: :cascade do |t|
    t.bigint "blocked_id", null: false
    t.string "blocked_type", null: false
    t.bigint "blocker_id", null: false
    t.string "blocker_type", null: false
    t.datetime "created_at", null: false
    t.text "reason"
    t.datetime "updated_at", null: false
    t.index ["blocked_type", "blocked_id"], name: "index_block_lists_on_blocked_type_and_blocked_id"
    t.index ["blocker_type", "blocker_id", "blocked_type", "blocked_id"], name: "index_block_lists_unique", unique: true
    t.index ["blocker_type", "blocker_id"], name: "index_block_lists_on_blocker_type_and_blocker_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "billing_address_line_1"
    t.string "billing_address_line_2"
    t.string "billing_city"
    t.string "billing_email"
    t.string "billing_phone"
    t.string "billing_state"
    t.string "billing_zip_code"
    t.datetime "created_at", null: false
    t.string "industry"
    t.boolean "is_active", default: true
    t.string "name", null: false
    t.bigint "owner_employer_profile_id"
    t.string "payment_terms"
    t.string "tax_id"
    t.text "typical_roles"
    t.datetime "updated_at", null: false
    t.string "workers_needed_per_week"
    t.index ["name"], name: "index_companies_on_name"
    t.index ["owner_employer_profile_id"], name: "index_companies_on_owner_employer_profile_id"
  end

  create_table "employer_profiles", force: :cascade do |t|
    t.boolean "can_approve_timesheets", default: false
    t.boolean "can_post_shifts", default: true
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "first_name", null: false
    t.boolean "is_billing_contact", default: false
    t.string "last_name", null: false
    t.datetime "msa_accepted_at"
    t.boolean "onboarding_completed", default: false
    t.string "phone", null: false
    t.datetime "terms_accepted_at"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["company_id"], name: "index_employer_profiles_on_company_id"
    t.index ["user_id"], name: "index_employer_profiles_on_user_id", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.text "body", null: false
    t.integer "channel", null: false
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.integer "direction", null: false
    t.datetime "failed_at"
    t.string "from_phone"
    t.bigint "in_reply_to_message_id"
    t.integer "message_type", default: 0
    t.bigint "messageable_id", null: false
    t.string "messageable_type", null: false
    t.datetime "read_at"
    t.datetime "sent_at"
    t.bigint "shift_assignment_id"
    t.bigint "shift_id"
    t.string "sms_error_code"
    t.text "sms_error_message"
    t.integer "sms_status"
    t.string "subject"
    t.uuid "thread_id"
    t.string "to_phone"
    t.string "twilio_message_sid"
    t.datetime "updated_at", null: false
    t.index ["in_reply_to_message_id"], name: "index_messages_on_in_reply_to_message_id"
    t.index ["messageable_type", "messageable_id", "sent_at"], name: "index_messages_on_messageable_and_sent_at"
    t.index ["messageable_type", "messageable_id"], name: "index_messages_on_messageable_type_and_messageable_id"
    t.index ["sent_at"], name: "index_messages_on_sent_at"
    t.index ["shift_assignment_id"], name: "index_messages_on_shift_assignment_id"
    t.index ["shift_id"], name: "index_messages_on_shift_id"
    t.index ["thread_id"], name: "index_messages_on_thread_id"
    t.index ["twilio_message_sid"], name: "index_messages_on_twilio_message_sid", unique: true
  end

  create_table "payments", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.text "dispute_reason"
    t.text "dispute_resolution"
    t.datetime "dispute_resolved_at"
    t.datetime "disputed_at"
    t.string "external_transaction_id"
    t.datetime "failed_at"
    t.text "failure_reason"
    t.decimal "hours_worked", precision: 5, scale: 2
    t.boolean "included_in_1099", default: false
    t.integer "pay_rate_cents"
    t.integer "payment_method", default: 0
    t.datetime "processed_at"
    t.text "refund_reason"
    t.datetime "refunded_at"
    t.bigint "shift_assignment_id", null: false
    t.integer "status", default: 0, null: false
    t.integer "tax_year"
    t.datetime "updated_at", null: false
    t.bigint "worker_profile_id", null: false
    t.index ["company_id"], name: "index_payments_on_company_id"
    t.index ["shift_assignment_id"], name: "index_payments_on_shift_assignment_id", unique: true
    t.index ["status"], name: "index_payments_on_status"
    t.index ["tax_year"], name: "index_payments_on_tax_year"
    t.index ["worker_profile_id", "tax_year"], name: "index_payments_on_worker_and_tax_year"
    t.index ["worker_profile_id"], name: "index_payments_on_worker_profile_id"
  end

  create_table "shift_assignments", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "actual_end_time"
    t.decimal "actual_hours_worked", precision: 5, scale: 2
    t.datetime "actual_start_time"
    t.decimal "algorithm_score", precision: 5, scale: 2
    t.datetime "assigned_at", null: false
    t.integer "assigned_by", default: 0
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.integer "cancelled_by"
    t.datetime "checked_in_at"
    t.datetime "checked_out_at"
    t.boolean "completed_successfully"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.text "decline_reason"
    t.decimal "distance_miles", precision: 5, scale: 2
    t.text "employer_feedback"
    t.integer "employer_rating"
    t.boolean "no_show", default: false
    t.integer "response_method"
    t.datetime "response_received_at"
    t.integer "response_value"
    t.bigint "shift_id", null: false
    t.datetime "sms_delivered_at"
    t.datetime "sms_sent_at"
    t.integer "status", default: 0, null: false
    t.datetime "timesheet_approved_at"
    t.bigint "timesheet_approved_by_employer_id"
    t.datetime "updated_at", null: false
    t.text "worker_feedback"
    t.bigint "worker_profile_id", null: false
    t.integer "worker_rating"
    t.index ["assigned_at"], name: "index_shift_assignments_on_assigned_at"
    t.index ["shift_id", "worker_profile_id"], name: "index_shift_assignments_unique", unique: true
    t.index ["shift_id"], name: "index_shift_assignments_on_shift_id"
    t.index ["status", "assigned_at"], name: "index_shift_assignments_on_status_and_assigned_at"
    t.index ["status"], name: "index_shift_assignments_on_status"
    t.index ["timesheet_approved_by_employer_id"], name: "index_shift_assignments_on_timesheet_approved_by_employer_id"
    t.index ["worker_profile_id"], name: "index_shift_assignments_on_worker_profile_id"
  end

  create_table "shifts", force: :cascade do |t|
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.bigint "company_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "created_by_employer_id", null: false
    t.text "description", null: false
    t.datetime "end_datetime", null: false
    t.datetime "filled_at"
    t.string "job_type", null: false
    t.integer "min_workers_needed", default: 1
    t.integer "pay_rate_cents", null: false
    t.text "physical_requirements"
    t.datetime "posted_at"
    t.datetime "recruiting_started_at"
    t.text "skills_required"
    t.integer "slots_filled", default: 0
    t.integer "slots_total", default: 1
    t.datetime "start_datetime", null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.string "tracking_code", null: false
    t.datetime "updated_at", null: false
    t.bigint "work_location_id", null: false
    t.index ["company_id"], name: "index_shifts_on_company_id"
    t.index ["created_by_employer_id"], name: "index_shifts_on_created_by_employer_id"
    t.index ["job_type"], name: "index_shifts_on_job_type"
    t.index ["start_datetime"], name: "index_shifts_on_start_datetime"
    t.index ["status", "start_datetime"], name: "index_shifts_on_status_and_start_datetime"
    t.index ["status"], name: "index_shifts_on_status"
    t.index ["tracking_code"], name: "index_shifts_on_tracking_code", unique: true
    t.index ["work_location_id"], name: "index_shifts_on_work_location_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "jti", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "work_locations", force: :cascade do |t|
    t.string "address_line_1", null: false
    t.string "address_line_2"
    t.text "arrival_instructions"
    t.string "city", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "name", null: false
    t.text "parking_notes"
    t.string "state", null: false
    t.datetime "updated_at", null: false
    t.string "zip_code", null: false
    t.index ["company_id"], name: "index_work_locations_on_company_id"
    t.index ["latitude", "longitude"], name: "index_work_locations_on_coordinates"
  end

  create_table "worker_availabilities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "day_of_week", null: false
    t.time "end_time", null: false
    t.boolean "is_active", default: true
    t.time "start_time", null: false
    t.datetime "updated_at", null: false
    t.bigint "worker_profile_id", null: false
    t.index ["worker_profile_id", "day_of_week", "start_time", "end_time"], name: "index_worker_availabilities_on_profile_day_time", unique: true
    t.index ["worker_profile_id", "day_of_week"], name: "index_worker_avail_on_profile_and_day"
    t.index ["worker_profile_id"], name: "index_worker_availabilities_on_worker_profile_id"
  end

  create_table "worker_preferred_job_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "job_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "worker_profile_id", null: false
    t.index ["worker_profile_id", "job_type"], name: "index_worker_pref_job_types_unique", unique: true
    t.index ["worker_profile_id"], name: "index_worker_preferred_job_types_on_worker_profile_id"
  end

  create_table "worker_profiles", force: :cascade do |t|
    t.string "address_line_1", null: false
    t.string "address_line_2"
    t.decimal "average_rating", precision: 3, scale: 2
    t.integer "average_response_time_minutes"
    t.string "bank_account_last_4"
    t.string "city", null: false
    t.datetime "created_at", null: false
    t.string "first_name", null: false
    t.boolean "is_active", default: true
    t.string "last_name", null: false
    t.datetime "last_sms_response_at"
    t.datetime "last_sms_sent_at"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.integer "no_show_count", default: 0
    t.boolean "onboarding_completed", default: false
    t.boolean "over_18_confirmed", default: false
    t.string "phone", null: false
    t.integer "preferred_payment_method", default: 0
    t.decimal "reliability_score", precision: 5, scale: 2
    t.datetime "sms_consent_given_at"
    t.string "ssn_encrypted"
    t.string "state", default: "TX", null: false
    t.datetime "terms_accepted_at"
    t.integer "total_shifts_assigned", default: 0
    t.integer "total_shifts_completed", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "zip_code", null: false
    t.index ["latitude", "longitude"], name: "index_worker_profiles_on_coordinates"
    t.index ["phone"], name: "index_worker_profiles_on_phone", unique: true
    t.index ["user_id"], name: "index_worker_profiles_on_user_id", unique: true
    t.index ["zip_code"], name: "index_worker_profiles_on_zip_code"
  end

  add_foreign_key "companies", "employer_profiles", column: "owner_employer_profile_id"
  add_foreign_key "employer_profiles", "companies"
  add_foreign_key "employer_profiles", "users"
  add_foreign_key "messages", "messages", column: "in_reply_to_message_id"
  add_foreign_key "messages", "shift_assignments"
  add_foreign_key "messages", "shifts"
  add_foreign_key "payments", "companies"
  add_foreign_key "payments", "shift_assignments"
  add_foreign_key "payments", "worker_profiles"
  add_foreign_key "shift_assignments", "employer_profiles", column: "timesheet_approved_by_employer_id"
  add_foreign_key "shift_assignments", "shifts"
  add_foreign_key "shift_assignments", "worker_profiles"
  add_foreign_key "shifts", "companies"
  add_foreign_key "shifts", "employer_profiles", column: "created_by_employer_id"
  add_foreign_key "shifts", "work_locations"
  add_foreign_key "work_locations", "companies"
  add_foreign_key "worker_availabilities", "worker_profiles"
  add_foreign_key "worker_preferred_job_types", "worker_profiles"
  add_foreign_key "worker_profiles", "users"
end
