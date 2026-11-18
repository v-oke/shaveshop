require "test_helper"

class InboundMessageTest < ActiveSupport::TestCase
  test "stores a central-number message before a salon is identified" do
    inbound = InboundMessage.create!(
      provider_message_id: "wamid-central-1",
      sender_id: "254700000000",
      received_at: Time.current,
      payload: { "message" => { "text" => { "body" => "BOOK BLADE1" } } }
    )

    assert_nil inbound.salon
    assert inbound.pending?
  end
end
