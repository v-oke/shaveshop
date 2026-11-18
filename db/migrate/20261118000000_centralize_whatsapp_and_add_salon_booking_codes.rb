class CentralizeWhatsappAndAddSalonBookingCodes < ActiveRecord::Migration[8.1]
  def up
    add_column :salons, :booking_code, :string
    execute <<~SQL
      UPDATE salons
      SET booking_code = 'S' || LPAD(id::text, 6, '0')
    SQL
    change_column_null :salons, :booking_code, false
    add_index :salons, :booking_code, unique: true

    remove_index :salons, name: "index_salons_on_whatsapp_phone_number_id"
    remove_column :salons, :whatsapp_phone_number_id
    change_column_null :inbound_messages, :salon_id, true
    create_table :whatsapp_contacts do |t|
      t.string :sender_id, null: false
      t.references :active_salon, foreign_key: { to_table: :salons }
      t.references :pending_salon, foreign_key: { to_table: :salons }
      t.string :state, null: false, default: "awaiting_salon"
      t.timestamps
    end

    add_index :whatsapp_contacts, :sender_id, unique: true
    add_check_constraint :whatsapp_contacts,
      "state IN ('awaiting_salon', 'choosing_previous_salon', 'active')",
      name: "whatsapp_contacts_state_check"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "salon-specific WhatsApp phone IDs were removed"
  end
end
