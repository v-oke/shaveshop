require "test_helper"

class WhatsappContactTest < ActiveSupport::TestCase
  test "tracks one platform contact and its salon selection" do
    salon = Salon.create!(name: "Blade", booking_code: "BLADE1")
    contact = WhatsappContact.create!(sender_id: "254700000000", active_salon: salon, state: :active)

    assert_equal salon, contact.active_salon
    assert_equal contact, salon.active_whatsapp_contacts.first
  end

  test "requires an active salon once the contact is active" do
    contact = WhatsappContact.new(sender_id: "254700000000", state: :active)

    assert_not contact.valid?
    assert_includes contact.errors[:active_salon], "is required for an active contact"
  end

  test "allows a customer to be represented once across all salons" do
    WhatsappContact.create!(sender_id: "254700000000")
    duplicate = WhatsappContact.new(sender_id: "254700000000")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:sender_id], "has already been taken"
  end
end
