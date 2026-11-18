module Whatsapp
  class SalonRouter
    attr_reader :salon

    def initialize(inbound_message:)
      @inbound_message = inbound_message
      @payload = inbound_message.payload
      @message = @payload.fetch("message", {})
      @sender_id = inbound_message.sender_id
      @received_at = inbound_message.received_at
      @display_name = @payload["display_name"].to_s.strip.presence
    end

    def call
      contact = WhatsappContact.find_or_create_by!(sender_id: sender_id)
      contact.with_lock do
        if (code = booking_code)
          select_by_code(contact, code)
        elsif contact.choosing_previous_salon?
          handle_previous_choice(contact)
        elsif contact.choosing_another_salon?
          prompt_for_code
        elsif contact.active? && recent_session?(contact)
          @salon = contact.active_salon
          @inbound_message.update!(salon: salon)
          welcome_back
        else
          ask_which_salon(contact)
        end
      end
    end

    private

    attr_reader :sender_id, :received_at, :display_name, :message

    def select_by_code(contact, code)
      selected_salon = Salon.find_by(booking_code: code)
      return text("I couldn't find that salon code. Check it and try again, or open the salon's booking link.") unless selected_salon

      activate_salon(contact, selected_salon)
      welcome("Welcome to #{selected_salon.name}! How can we help you today?")
    end

    def handle_previous_choice(contact)
      selected_id = reply_id
      if selected_id == "salon:choose" || text_body.casecmp("choose another salon").zero?
        contact.update!(state: :choosing_another_salon, active_salon: nil, pending_salon: nil)
        return prompt_for_code
      end

      if selected_id == "salon:continue:#{contact.pending_salon_id}"
        selected_salon = contact.pending_salon
        activate_salon(contact, selected_salon)
        return welcome("Welcome back to #{selected_salon.name}! How can we help you today?")
      end

      ask_to_continue(contact.pending_salon)
    end

    def ask_which_salon(contact)
      previous_customer = Customer.joins(:conversation)
        .where(whatsapp_sender_id: sender_id)
        .order(Arel.sql("conversations.last_inbound_at DESC NULLS LAST, conversations.updated_at DESC"))
        .first

      if previous_customer
        contact.update!(state: :choosing_previous_salon, active_salon: nil, pending_salon: previous_customer.salon)
        ask_to_continue(previous_customer.salon)
      else
        contact.update!(state: :awaiting_salon, active_salon: nil, pending_salon: nil)
        prompt_for_code
      end
    end

    def ask_to_continue(previous_salon)
      buttons(
        "Would you like to continue with #{previous_salon.name} or choose another salon?",
        [
          { id: "salon:continue:#{previous_salon.id}", title: "Continue #{previous_salon.name.truncate(10)}" },
          { id: "salon:choose", title: "Choose Another" }
        ]
      )
    end

    def prompt_for_code
      text("Welcome! To book an appointment, enter the salon's booking code or open its booking link.")
    end

    def activate_salon(contact, selected_salon)
      @salon = selected_salon
      customer = salon.customers.find_or_initialize_by(whatsapp_sender_id: sender_id)
      customer.display_name = display_name if customer.display_name.blank? && display_name.present?
      customer.phone_e164 ||= "+#{sender_id}" if sender_id.length <= 15
      customer.save! if customer.new_record? || customer.changed?

      conversation = Conversation.find_or_initialize_by(salon: salon, customer: customer)
      conversation.update!(
        state: :idle,
        draft_json: {},
        displayed_options_json: [],
        last_inbound_at: received_at,
        expires_at: received_at + 24.hours
      )
      contact.update!(state: :active, active_salon: salon, pending_salon: nil)
      @inbound_message.update!(salon: salon)
    end

    def recent_session?(contact)
      conversation = contact.active_salon&.customers&.find_by(whatsapp_sender_id: sender_id)&.conversation
      @conversation = conversation
      conversation&.expires_at&.>(received_at)
    end

    def welcome_back
      welcome("Welcome back to #{salon.name}. Choose an option to continue.")
    end

    def welcome(body)
      buttons(body, [
        { id: "menu:book", title: "Book Appointment" },
        { id: "menu:services", title: "View Services" },
        { id: "menu:appointments", title: "My Appointments" }
      ])
    end

    def buttons(body, options)
      { "type" => "buttons", "body" => body, "buttons" => options.map(&:stringify_keys) }
    end

    def text(body)
      { "type" => "text", "body" => body }
    end

    def booking_code
      match = text_body.match(/\ABOOK\s+([A-Z0-9]{4,12})\z/i)
      return match[1].upcase if match

      return unless text_body.match?(/\A[A-Z0-9]{4,12}\z/i)

      code = text_body.upcase
      code if Salon.exists?(booking_code: code)
    end

    def text_body
      message.dig("text", "body").to_s.strip
    end

    def reply_id
      message.dig("interactive", "button_reply", "id") || ""
    end
  end
end
