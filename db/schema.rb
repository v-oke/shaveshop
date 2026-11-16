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

ActiveRecord::Schema[8.1].define(version: 2026_10_04_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"

  create_table "booking_events", force: :cascade do |t|
    t.bigint "actor_staff_id"
    t.bigint "booking_id", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.jsonb "metadata_json", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.bigint "salon_id", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_staff_id"], name: "index_booking_events_on_actor_staff_id"
    t.index ["booking_id"], name: "index_booking_events_on_booking_id"
    t.index ["salon_id", "booking_id", "id"], name: "index_event_booking_identity", unique: true
    t.index ["salon_id", "id"], name: "index_booking_events_on_salon_id_and_id", unique: true
    t.index ["salon_id"], name: "index_booking_events_on_salon_id"
  end

  create_table "bookings", force: :cascade do |t|
    t.datetime "arrived_at"
    t.datetime "cancelled_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "customer_id"
    t.string "customer_name_snapshot", null: false
    t.integer "duration_snapshot", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "no_show_at"
    t.integer "price_minor_snapshot", null: false
    t.string "reference", null: false
    t.bigint "salon_id", null: false
    t.datetime "scheduled_end_at", null: false
    t.datetime "scheduled_start_at", null: false
    t.date "service_date", null: false
    t.bigint "service_id", null: false
    t.string "source", null: false
    t.bigint "staff_id", null: false
    t.datetime "started_at"
    t.string "status", default: "confirmed", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_bookings_on_customer_id"
    t.index ["salon_id", "customer_id", "service_date"], name: "one_active_customer_booking_per_day", unique: true, where: "((customer_id IS NOT NULL) AND ((status)::text = ANY (ARRAY[('confirmed'::character varying)::text, ('waiting'::character varying)::text, ('in_progress'::character varying)::text])))"
    t.index ["salon_id", "id"], name: "index_bookings_on_salon_id_and_id", unique: true
    t.index ["salon_id", "reference"], name: "index_bookings_on_salon_id_and_reference", unique: true
    t.index ["salon_id", "staff_id", "scheduled_start_at", "status"], name: "index_bookings_schedule"
    t.index ["salon_id"], name: "index_bookings_on_salon_id"
    t.index ["service_id"], name: "index_bookings_on_service_id"
    t.index ["staff_id"], name: "index_bookings_on_staff_id"
    t.index ["staff_id"], name: "one_service_per_barber", unique: true, where: "((status)::text = 'in_progress'::text)"
    t.check_constraint "price_minor_snapshot >= 0 AND duration_snapshot > 0", name: "bookings_check_0"
    t.check_constraint "scheduled_end_at = (scheduled_start_at + duration_snapshot::double precision * 'PT1M'::interval)", name: "bookings_check_1"
    t.check_constraint "source::text <> 'whatsapp'::text OR customer_id IS NOT NULL", name: "bookings_check_3"
    t.check_constraint "source::text = ANY (ARRAY['whatsapp'::character varying::text, 'walk_in'::character varying::text])", name: "bookings_check_2"
    t.check_constraint "status::text = ANY (ARRAY['confirmed'::character varying::text, 'waiting'::character varying::text, 'in_progress'::character varying::text, 'completed'::character varying::text, 'cancelled'::character varying::text, 'no_show'::character varying::text])", name: "bookings_check_4"
    t.exclusion_constraint "staff_id WITH =, tsrange(scheduled_start_at, scheduled_end_at, '[)'::text) WITH &&", where: "(status)::text = ANY (ARRAY[('confirmed'::character varying)::text, ('waiting'::character varying)::text, ('in_progress'::character varying)::text])", using: :gist, name: "no_overlapping_active_bookings"
  end

  create_table "conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.jsonb "displayed_options_json", default: [], null: false
    t.jsonb "draft_json", default: {}, null: false
    t.datetime "expires_at"
    t.datetime "last_inbound_at"
    t.bigint "salon_id", null: false
    t.string "state", default: "idle", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_conversations_on_customer_id"
    t.index ["salon_id", "customer_id"], name: "index_conversations_on_salon_id_and_customer_id", unique: true
    t.index ["salon_id", "id"], name: "index_conversations_on_salon_id_and_id", unique: true
    t.index ["salon_id"], name: "index_conversations_on_salon_id"
    t.check_constraint "state::text = ANY (ARRAY['idle'::character varying::text, 'choosing_service'::character varying::text, 'choosing_date'::character varying::text, 'choosing_slot'::character varying::text, 'collecting_name'::character varying::text, 'reviewing'::character varying::text, 'booked'::character varying::text, 'cancelling'::character varying::text])", name: "conversations_check_0"
  end

  create_table "customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "phone_e164"
    t.datetime "preference_updated_at"
    t.boolean "queue_updates_enabled", default: true, null: false
    t.bigint "salon_id", null: false
    t.datetime "updated_at", null: false
    t.string "whatsapp_sender_id", null: false
    t.index ["salon_id", "id"], name: "index_customers_on_salon_id_and_id", unique: true
    t.index ["salon_id", "whatsapp_sender_id"], name: "index_customers_on_salon_id_and_whatsapp_sender_id", unique: true
    t.index ["salon_id"], name: "index_customers_on_salon_id"
  end

  create_table "inbound_messages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "payload", default: {}, null: false
    t.string "processing_status", default: "pending", null: false
    t.string "provider_message_id", null: false
    t.datetime "received_at", null: false
    t.bigint "salon_id", null: false
    t.string "sender_id", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_message_id"], name: "index_inbound_messages_on_provider_message_id", unique: true
    t.index ["salon_id", "id"], name: "index_inbound_messages_on_salon_id_and_id", unique: true
    t.index ["salon_id"], name: "index_inbound_messages_on_salon_id"
    t.check_constraint "processing_status::text = ANY (ARRAY['pending'::character varying::text, 'processing'::character varying::text, 'processed'::character varying::text, 'failed'::character varying::text])", name: "inbound_messages_check_0"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.bigint "booking_id", null: false
    t.text "content_snapshot", null: false
    t.datetime "created_at", null: false
    t.string "dedupe_key", null: false
    t.datetime "delivered_at"
    t.bigint "event_id", null: false
    t.string "kind", null: false
    t.text "last_error"
    t.string "milestone"
    t.datetime "next_attempt_at"
    t.string "provider_message_id"
    t.bigint "salon_id", null: false
    t.string "status", default: "queued", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_notifications_on_booking_id"
    t.index ["dedupe_key"], name: "index_notifications_on_dedupe_key", unique: true
    t.index ["event_id"], name: "index_notifications_on_event_id"
    t.index ["salon_id", "id"], name: "index_notifications_on_salon_id_and_id", unique: true
    t.index ["salon_id"], name: "index_notifications_on_salon_id"
    t.index ["status", "next_attempt_at"], name: "index_notifications_on_status_and_next_attempt_at"
    t.check_constraint "attempts >= 0", name: "notifications_check_0"
    t.check_constraint "status::text = ANY (ARRAY['queued'::character varying::text, 'sending'::character varying::text, 'accepted'::character varying::text, 'delivered'::character varying::text, 'failed'::character varying::text, 'suppressed'::character varying::text])", name: "notifications_check_1"
  end

  create_table "opening_hours", force: :cascade do |t|
    t.time "closes_at_local", null: false
    t.datetime "created_at", null: false
    t.time "opens_at_local", null: false
    t.bigint "salon_id", null: false
    t.datetime "updated_at", null: false
    t.integer "weekday", null: false
    t.index ["salon_id", "id"], name: "index_opening_hours_on_salon_id_and_id", unique: true
    t.index ["salon_id", "weekday"], name: "index_opening_hours_on_salon_id_and_weekday", unique: true
    t.index ["salon_id"], name: "index_opening_hours_on_salon_id"
    t.check_constraint "closes_at_local > opens_at_local", name: "opening_hours_check_1"
    t.check_constraint "weekday >= 0 AND weekday <= 6", name: "opening_hours_check_0"
  end

  create_table "salons", force: :cascade do |t|
    t.text "address"
    t.integer "booking_horizon_days", default: 30, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "KES", null: false
    t.integer "grace_minutes", default: 10, null: false
    t.string "name", null: false
    t.integer "slot_step_minutes", default: 15, null: false
    t.string "timezone", default: "Africa/Nairobi", null: false
    t.datetime "updated_at", null: false
    t.string "whatsapp_phone_number_id", null: false
    t.index ["whatsapp_phone_number_id"], name: "index_salons_on_whatsapp_phone_number_id", unique: true
    t.check_constraint "booking_horizon_days > 0 AND slot_step_minutes > 0 AND grace_minutes >= 0", name: "salons_check_0"
  end

  create_table "services", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "duration_minutes", null: false
    t.string "name", null: false
    t.integer "price_minor", null: false
    t.bigint "salon_id", null: false
    t.datetime "updated_at", null: false
    t.index ["salon_id", "id"], name: "index_services_on_salon_id_and_id", unique: true
    t.index ["salon_id"], name: "index_services_on_salon_id"
    t.check_constraint "price_minor >= 0 AND duration_minutes > 0", name: "services_check_0"
  end

  create_table "staff", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "role", default: "barber", null: false
    t.bigint "salon_id", null: false
    t.datetime "updated_at", null: false
    t.index ["salon_id", "email"], name: "index_staff_on_salon_id_and_email", unique: true
    t.index ["salon_id", "id"], name: "index_staff_on_salon_id_and_id", unique: true
    t.index ["salon_id"], name: "index_staff_on_salon_id"
    t.check_constraint "role::text = ANY (ARRAY['owner'::character varying::text, 'barber'::character varying::text])", name: "staff_check_0"
  end

  create_table "staff_availabilities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ends_at", null: false
    t.date "local_date", null: false
    t.bigint "salon_id", null: false
    t.bigint "staff_id", null: false
    t.datetime "starts_at", null: false
    t.datetime "updated_at", null: false
    t.index ["salon_id", "id"], name: "index_staff_availabilities_on_salon_id_and_id", unique: true
    t.index ["salon_id", "staff_id", "local_date"], name: "index_staff_availability_date"
    t.index ["salon_id"], name: "index_staff_availabilities_on_salon_id"
    t.index ["staff_id"], name: "index_staff_availabilities_on_staff_id"
    t.check_constraint "ends_at > starts_at", name: "staff_availabilities_check_0"
  end

  add_foreign_key "booking_events", "bookings"
  add_foreign_key "booking_events", "bookings", column: ["salon_id", "booking_id"], primary_key: ["salon_id", "id"]
  add_foreign_key "booking_events", "salons"
  add_foreign_key "booking_events", "staff", column: "actor_staff_id"
  add_foreign_key "booking_events", "staff", column: ["salon_id", "actor_staff_id"], primary_key: ["salon_id", "id"]
  add_foreign_key "bookings", "customers"
  add_foreign_key "bookings", "customers", column: ["salon_id", "customer_id"], primary_key: ["salon_id", "id"]
  add_foreign_key "bookings", "salons"
  add_foreign_key "bookings", "services"
  add_foreign_key "bookings", "services", column: ["salon_id", "service_id"], primary_key: ["salon_id", "id"]
  add_foreign_key "bookings", "staff"
  add_foreign_key "bookings", "staff", column: ["salon_id", "staff_id"], primary_key: ["salon_id", "id"]
  add_foreign_key "conversations", "customers"
  add_foreign_key "conversations", "customers", column: ["salon_id", "customer_id"], primary_key: ["salon_id", "id"]
  add_foreign_key "conversations", "salons"
  add_foreign_key "customers", "salons"
  add_foreign_key "inbound_messages", "salons"
  add_foreign_key "notifications", "booking_events", column: "event_id"
  add_foreign_key "notifications", "booking_events", column: ["salon_id", "booking_id", "event_id"], primary_key: ["salon_id", "booking_id", "id"], name: "notification_event_matches_booking"
  add_foreign_key "notifications", "booking_events", column: ["salon_id", "event_id"], primary_key: ["salon_id", "id"]
  add_foreign_key "notifications", "bookings"
  add_foreign_key "notifications", "bookings", column: ["salon_id", "booking_id"], primary_key: ["salon_id", "id"]
  add_foreign_key "notifications", "salons"
  add_foreign_key "opening_hours", "salons"
  add_foreign_key "services", "salons"
  add_foreign_key "staff", "salons"
  add_foreign_key "staff_availabilities", "salons"
  add_foreign_key "staff_availabilities", "staff"
  add_foreign_key "staff_availabilities", "staff", column: ["salon_id", "staff_id"], primary_key: ["salon_id", "id"]
end
