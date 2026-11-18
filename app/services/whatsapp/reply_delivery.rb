module Whatsapp
  class ReplyDelivery
    def initialize(recipient:, reply:)
      @recipient = recipient
      @reply = reply
    end

    def call
      return if reply.blank?

      client = CloudApi.new
      phone_number_id = ENV["WHATSAPP_PHONE_NUMBER_ID"]
      case reply["type"]
      when "text"
        client.send_text(phone_number_id: phone_number_id, recipient: recipient, text: reply.fetch("body"))
      when "buttons"
        client.send_buttons(
          phone_number_id: phone_number_id,
          recipient: recipient,
          body: reply.fetch("body"),
          buttons: reply.fetch("buttons").map(&:symbolize_keys)
        )
      else
        raise ArgumentError, "unsupported WhatsApp reply type"
      end
    end

    private

    attr_reader :recipient, :reply
  end
end
