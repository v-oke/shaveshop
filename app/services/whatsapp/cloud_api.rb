require "net/http"
require "json"
require "openssl"

module Whatsapp
  class CloudApi
    class Error < StandardError
      attr_reader :retryable

      def initialize(message, retryable: false)
        super(message)
        @retryable = retryable
      end
    end

    def initialize(access_token: ENV["WHATSAPP_ACCESS_TOKEN"], api_version: ENV.fetch("WHATSAPP_GRAPH_API_VERSION", "v27.0"))
      @access_token = access_token
      @api_version = api_version
    end

    def send_text(phone_number_id:, recipient:, text:)
      post_message(phone_number_id, {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to: recipient,
        type: "text",
        text: { preview_url: false, body: text }
      })
    end

    def send_template(phone_number_id:, recipient:, name:, language:, body_parameter:)
      post_message(phone_number_id, {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to: recipient,
        type: "template",
        template: {
          name: name,
          language: { code: language },
          components: [ {
            type: "body",
            parameters: [ { type: "text", text: body_parameter } ]
          } ]
        }
      })
    end

    def send_buttons(phone_number_id:, recipient:, body:, buttons:)
      raise ArgumentError, "WhatsApp interactive messages support up to three buttons" unless buttons.length.between?(1, 3)

      post_message(phone_number_id, {
        messaging_product: "whatsapp",
        recipient_type: "individual",
        to: recipient,
        type: "interactive",
        interactive: {
          type: "button",
          body: { text: body },
          action: {
            buttons: buttons.map do |button|
              { type: "reply", reply: { id: button.fetch(:id), title: button.fetch(:title) } }
            end
          }
        }
      })
    end

    private

    attr_reader :access_token, :api_version

    def post_message(phone_number_id, payload)
      raise Error, "WHATSAPP_ACCESS_TOKEN is not configured" if access_token.blank?
      raise Error, "WhatsApp phone number ID is missing" if phone_number_id.blank?
      raise Error, "WhatsApp phone number ID must contain only digits" unless phone_number_id.to_s.match?(/\A\d+\z/)
      raise Error, "WHATSAPP_GRAPH_API_VERSION is invalid" unless api_version.match?(/\Av\d+\.\d+\z/)
      raise Error, "WhatsApp recipient is missing" if payload[:to].blank?

      uri = URI("https://graph.facebook.com/#{api_version}/#{phone_number_id}/messages")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 20) do |http|
        http.request(request)
      end
      parsed = JSON.parse(response.body)

      unless response.is_a?(Net::HTTPSuccess)
        provider_error = parsed.dig("error", "message") || "WhatsApp API returned HTTP #{response.code}"
        retryable = response.code.to_i == 408 || response.code.to_i == 429 || response.code.to_i >= 500
        raise Error.new(provider_error, retryable: retryable)
      end

      message_id = parsed.dig("messages", 0, "id")
      raise Error.new("WhatsApp API response did not include a message ID", retryable: true) if message_id.blank?

      message_id
    rescue JSON::ParserError
      raise Error.new("WhatsApp API returned an invalid response", retryable: true)
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError => error
      raise Error.new("WhatsApp API request failed: #{error.class}", retryable: true)
    end
  end
end
