require "test_helper"

class Whatsapp::SalonRouterTest < ActiveSupport::TestCase
  setup do
    @salon = Salon.create!(name: "Blade", booking_code: "BLADE1")
    @other_salon = Salon.create!(name: "Other", booking_code: "OTHER1")
    @sender_id = "254700000000"
  end

  test "booking code selects a salon and creates its scoped customer conversation" do
    inbound = inbound_message("BOOK BLADE1")
    response = Whatsapp::SalonRouter.new(inbound_message: inbound).call

    contact = WhatsappContact.find_by!(sender_id: @sender_id)
    assert_equal @salon, contact.active_salon
    assert_equal :active, contact.state.to_sym
    assert_equal @salon, inbound.reload.salon
    assert @salon.customers.exists?(whatsapp_sender_id: @sender_id)
    assert_equal 1, @salon.conversations.count
    assert_equal "buttons", response.fetch("type")
    assert_equal 3, response.fetch("buttons").length
  end

  test "switching salons leaves the previous salon conversation intact" do
    first_message = inbound_message("BOOK BLADE1")
    Whatsapp::SalonRouter.new(inbound_message: first_message).call
    old_conversation = @salon.conversations.first

    second_message = inbound_message("BOOK OTHER1")
    Whatsapp::SalonRouter.new(inbound_message: second_message).call

    assert_equal @other_salon, WhatsappContact.find_by!(sender_id: @sender_id).active_salon
    assert_equal old_conversation.id, @salon.conversations.first.id
    assert_equal @other_salon, second_message.reload.salon
  end

  test "asks an unknown customer for a booking code" do
    response = Whatsapp::SalonRouter.new(inbound_message: inbound_message("Hello")).call

    assert_equal "awaiting_salon", WhatsappContact.find_by!(sender_id: @sender_id).state
    assert_match(/booking code/i, response.fetch("body"))
  end

  test "asks a returning customer to confirm the previous salon" do
    customer = @salon.customers.create!(whatsapp_sender_id: @sender_id)
    @salon.conversations.create!(customer: customer, last_inbound_at: 1.day.ago)

    response = Whatsapp::SalonRouter.new(inbound_message: inbound_message("Hi again")).call

    contact = WhatsappContact.find_by!(sender_id: @sender_id)
    assert_equal "choosing_previous_salon", contact.state
    assert_nil contact.active_salon
    assert_equal @salon, contact.pending_salon
    assert_includes response.fetch("body"), @salon.name
    assert_equal "salon:continue:#{@salon.id}", response.dig("buttons", 0, "id")
  end

  private

  def inbound_message(body, id: SecureRandom.uuid)
    InboundMessage.create!(
      provider_message_id: id,
      sender_id: @sender_id,
      received_at: Time.current,
      payload: { "message" => { "text" => { "body" => body } }, "display_name" => "Sam" }
    )
  end
end
