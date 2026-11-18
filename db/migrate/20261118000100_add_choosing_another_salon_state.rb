class AddChoosingAnotherSalonState < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :whatsapp_contacts, name: "whatsapp_contacts_state_check"
    add_check_constraint :whatsapp_contacts,
      "state IN ('awaiting_salon', 'choosing_previous_salon', 'choosing_another_salon', 'active')",
      name: "whatsapp_contacts_state_check"
  end

  def down
    execute "UPDATE whatsapp_contacts SET state = 'awaiting_salon' WHERE state = 'choosing_another_salon'"
    remove_check_constraint :whatsapp_contacts, name: "whatsapp_contacts_state_check"
    add_check_constraint :whatsapp_contacts,
      "state IN ('awaiting_salon', 'choosing_previous_salon', 'active')",
      name: "whatsapp_contacts_state_check"
  end
end
