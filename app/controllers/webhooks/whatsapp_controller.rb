module Webhooks
  class WhatsappController < ActionController::API
    def verify
      mode = params["hub.mode"] || params.dig("hub", "mode")
      token = params["hub.verify_token"] || params.dig("hub", "verify_token")
      challenge = params["hub.challenge"] || params.dig("hub", "challenge")

      if mode == "subscribe" && secure_equal?(token, ENV["WHATSAPP_WEBHOOK_VERIFY_TOKEN"])
        render plain: challenge
      else
        head :forbidden
      end
    end

    def receive
      raw_body = request.raw_post
      return head :unauthorized unless valid_signature?(raw_body)
      return head :service_unavailable if ENV["WHATSAPP_PHONE_NUMBER_ID"].blank?

      payload = JSON.parse(raw_body)
      payload.fetch("entry", []).each do |entry|
        entry.fetch("changes", []).each do |change|
          value = change.fetch("value", {})
          metadata = value.fetch("metadata", {})
          next unless metadata["phone_number_id"] == ENV["WHATSAPP_PHONE_NUMBER_ID"]

          store_messages(value, metadata)
        end
      end

      head :ok
    rescue JSON::ParserError, KeyError
      head :bad_request
    end

    private

    def valid_signature?(body)
      app_secret = ENV["WHATSAPP_APP_SECRET"]
      signature = request.headers["X-Hub-Signature-256"]
      return false if app_secret.blank? || signature.blank?

      expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", app_secret, body)}"
      secure_equal?(signature, expected)
    end

    def secure_equal?(left, right)
      return false if left.blank? || right.blank? || left.bytesize != right.bytesize

      ActiveSupport::SecurityUtils.secure_compare(left, right)
    end

    def store_messages(value, metadata)
      profiles = value.fetch("contacts", []).index_by { |contact| contact["wa_id"] }

      value.fetch("messages", []).each do |message|
        sender_id = message["from"]
        provider_message_id = message["id"]
        next if sender_id.blank? || provider_message_id.blank?

        inbound = InboundMessage.create_or_find_by!(provider_message_id: provider_message_id) do |record|
          record.assign_attributes(
            sender_id: sender_id,
            received_at: Time.at(message.fetch("timestamp").to_i).utc,
            payload: {
              "message" => message,
              "display_name" => profiles.dig(sender_id, "profile", "name"),
              "phone_number_id" => metadata["phone_number_id"]
            }
          )
        end

        if inbound.previously_new_record?
          inbound_id = inbound.id
          ActiveRecord.after_all_transactions_commit do
            Whatsapp::ProcessInboundJob.perform_later(inbound_id)
          end
        end
      end
    end
  end
end
