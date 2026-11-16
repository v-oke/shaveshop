class CreateBookingDomain < ActiveRecord::Migration[8.1]
  def change
    enable_extension "btree_gist"

    create_table :salons do |t|
      t.string :name, null: false
      t.string :timezone, null: false, default: "Africa/Nairobi"
      t.string :currency, null: false, default: "KES"
      t.text :address, null: true
      t.string :whatsapp_phone_number_id, null: false
      t.integer :booking_horizon_days, null: false, default: 30
      t.integer :slot_step_minutes, null: false, default: 15
      t.integer :grace_minutes, null: false, default: 10
      t.timestamps
    end

    create_table :staff do |t|
      t.references :salon, null: false, foreign_key: true
      t.string :name, null: false
      t.string :role, null: false, default: "barber"
      t.string :email, null: false
      t.string :password_digest, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :staff, [ :salon_id, :id ], unique: true

    create_table :services do |t|
      t.references :salon, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :price_minor, null: false
      t.integer :duration_minutes, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :services, [ :salon_id, :id ], unique: true

    create_table :opening_hours do |t|
      t.references :salon, null: false, foreign_key: true
      t.integer :weekday, null: false
      t.time :opens_at_local, null: false
      t.time :closes_at_local, null: false
      t.timestamps
    end

    add_index :opening_hours, [ :salon_id, :id ], unique: true

    create_table :staff_availabilities do |t|
      t.references :salon, null: false, foreign_key: true
      t.references :staff, null: false, foreign_key: true
      t.date :local_date, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.timestamps
    end

    add_index :staff_availabilities, [ :salon_id, :id ], unique: true

    create_table :customers do |t|
      t.references :salon, null: false, foreign_key: true
      t.string :whatsapp_sender_id, null: false
      t.string :display_name, null: true
      t.string :phone_e164, null: true
      t.boolean :queue_updates_enabled, null: false, default: true
      t.datetime :preference_updated_at, null: true
      t.timestamps
    end

    add_index :customers, [ :salon_id, :id ], unique: true

    create_table :bookings do |t|
      t.references :salon, null: false, foreign_key: true
      t.references :customer, null: true, foreign_key: true
      t.references :staff, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.string :customer_name_snapshot, null: false
      t.string :source, null: false
      t.string :reference, null: false
      t.date :service_date, null: false
      t.datetime :scheduled_start_at, null: false
      t.datetime :scheduled_end_at, null: false
      t.integer :price_minor_snapshot, null: false
      t.integer :duration_snapshot, null: false
      t.string :status, null: false, default: "confirmed"
      t.datetime :arrived_at, null: true
      t.datetime :started_at, null: true
      t.datetime :completed_at, null: true
      t.datetime :cancelled_at, null: true
      t.datetime :no_show_at, null: true
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :bookings, [ :salon_id, :id ], unique: true

    create_table :conversations do |t|
      t.references :salon, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.string :state, null: false, default: "idle"
      t.jsonb :draft_json, null: false, default: {}
      t.jsonb :displayed_options_json, null: false, default: []
      t.datetime :last_inbound_at, null: true
      t.datetime :expires_at, null: true
      t.timestamps
    end

    add_index :conversations, [ :salon_id, :id ], unique: true

    create_table :booking_events do |t|
      t.references :salon, null: false, foreign_key: true
      t.references :booking, null: false, foreign_key: true
      t.string :event_type, null: false
      t.references :actor_staff, null: true, foreign_key: { to_table: :staff }
      t.datetime :occurred_at, null: false
      t.jsonb :metadata_json, null: false, default: {}
      t.timestamps
    end

    add_index :booking_events, [ :salon_id, :id ], unique: true

    create_table :inbound_messages do |t|
      t.references :salon, null: false, foreign_key: true
      t.string :provider_message_id, null: false
      t.string :sender_id, null: false
      t.datetime :received_at, null: false
      t.string :processing_status, null: false, default: "pending"
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end

    add_index :inbound_messages, [ :salon_id, :id ], unique: true

    create_table :notifications do |t|
      t.references :salon, null: false, foreign_key: true
      t.references :booking, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: { to_table: :booking_events }
      t.string :kind, null: false
      t.string :milestone, null: true
      t.string :dedupe_key, null: false
      t.text :content_snapshot, null: false
      t.string :provider_message_id, null: true
      t.string :status, null: false, default: "queued"
      t.integer :attempts, null: false, default: 0
      t.datetime :next_attempt_at, null: true
      t.text :last_error, null: true
      t.datetime :delivered_at, null: true
      t.timestamps
    end

    add_index :notifications, [ :salon_id, :id ], unique: true

    add_index :salons, [ :whatsapp_phone_number_id ], unique: true
    add_index :staff, [ :salon_id, :email ], unique: true
    add_index :opening_hours, [ :salon_id, :weekday ], unique: true
    add_index :customers, [ :salon_id, :whatsapp_sender_id ], unique: true
    add_index :bookings, [ :salon_id, :reference ], unique: true
    add_index :conversations, [ :salon_id, :customer_id ], unique: true
    add_index :inbound_messages, [ :provider_message_id ], unique: true
    add_index :notifications, [ :dedupe_key ], unique: true
    add_index :bookings, [ :salon_id, :staff_id, :scheduled_start_at, :status ], name: "index_bookings_schedule"
    add_index :bookings, :staff_id, unique: true, where: "status = 'in_progress'", name: "one_service_per_barber"
    add_index :bookings, [ :salon_id, :customer_id, :service_date ], unique: true,
      where: "customer_id IS NOT NULL AND status IN ('confirmed', 'waiting', 'in_progress')", name: "one_active_customer_booking_per_day"
    add_index :notifications, [ :status, :next_attempt_at ]
    add_index :staff_availabilities, [ :salon_id, :staff_id, :local_date ], name: "index_staff_availability_date"

    add_foreign_key :staff_availabilities, :staff, column: [ :salon_id, :staff_id ], primary_key: [ :salon_id, :id ]
    add_foreign_key :bookings, :customers, column: [ :salon_id, :customer_id ], primary_key: [ :salon_id, :id ]
    add_foreign_key :bookings, :staff, column: [ :salon_id, :staff_id ], primary_key: [ :salon_id, :id ]
    add_foreign_key :bookings, :services, column: [ :salon_id, :service_id ], primary_key: [ :salon_id, :id ]
    add_foreign_key :conversations, :customers, column: [ :salon_id, :customer_id ], primary_key: [ :salon_id, :id ]
    add_foreign_key :booking_events, :bookings, column: [ :salon_id, :booking_id ], primary_key: [ :salon_id, :id ]
    add_foreign_key :booking_events, :staff, column: [ :salon_id, :actor_staff_id ], primary_key: [ :salon_id, :id ]
    add_foreign_key :notifications, :bookings, column: [ :salon_id, :booking_id ], primary_key: [ :salon_id, :id ]
    add_foreign_key :notifications, :booking_events, column: [ :salon_id, :event_id ], primary_key: [ :salon_id, :id ]
    add_index :booking_events, [ :salon_id, :booking_id, :id ], unique: true, name: "index_event_booking_identity"
    add_foreign_key :notifications, :booking_events, column: [ :salon_id, :booking_id, :event_id ],
      primary_key: [ :salon_id, :booking_id, :id ], name: "notification_event_matches_booking"

    add_exclusion_constraint :bookings,
      "staff_id WITH =, tsrange(scheduled_start_at, scheduled_end_at, '[)') WITH &&",
      using: :gist, where: "status IN ('confirmed', 'waiting', 'in_progress')", name: "no_overlapping_active_bookings"
    add_check_constraint :salons, "booking_horizon_days > 0 AND slot_step_minutes > 0 AND grace_minutes >= 0", name: "salons_check_0"
    add_check_constraint :services, "price_minor >= 0 AND duration_minutes > 0", name: "services_check_0"
    add_check_constraint :opening_hours, "weekday BETWEEN 0 AND 6", name: "opening_hours_check_0"
    add_check_constraint :opening_hours, "closes_at_local > opens_at_local", name: "opening_hours_check_1"
    add_check_constraint :staff_availabilities, "ends_at > starts_at", name: "staff_availabilities_check_0"
    add_check_constraint :bookings, "price_minor_snapshot >= 0 AND duration_snapshot > 0", name: "bookings_check_0"
    add_check_constraint :bookings, "scheduled_end_at = scheduled_start_at + duration_snapshot * interval '1 minute'", name: "bookings_check_1"
    add_check_constraint :bookings, "source IN ('whatsapp', 'walk_in')", name: "bookings_check_2"
    add_check_constraint :bookings, "source <> 'whatsapp' OR customer_id IS NOT NULL", name: "bookings_check_3"
    add_check_constraint :bookings, "status IN ('confirmed', 'waiting', 'in_progress', 'completed', 'cancelled', 'no_show')", name: "bookings_check_4"
    add_check_constraint :notifications, "attempts >= 0", name: "notifications_check_0"
    add_check_constraint :notifications, "status IN ('queued', 'sending', 'accepted', 'delivered', 'failed', 'suppressed')", name: "notifications_check_1"
    add_check_constraint :staff, "role IN ('owner', 'barber')", name: "staff_check_0"
    add_check_constraint :conversations, "state IN ('idle', 'choosing_service', 'choosing_date', 'choosing_slot', 'collecting_name', 'reviewing', 'booked', 'cancelling')", name: "conversations_check_0"
    add_check_constraint :inbound_messages, "processing_status IN ('pending', 'processing', 'processed', 'failed')", name: "inbound_messages_check_0"
  end
end
