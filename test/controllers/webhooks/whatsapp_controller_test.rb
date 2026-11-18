require "test_helper"

class Webhooks::WhatsappControllerTest < ActionDispatch::IntegrationTest
  setup do
    @saved_env = %w[WHATSAPP_WEBHOOK_VERIFY_TOKEN WHATSAPP_APP_SECRET WHATSAPP_PHONE_NUMBER_ID].to_h do |key|
      [ key, ENV[key] ]
    end
    ENV["WHATSAPP_WEBHOOK_VERIFY_TOKEN"] = "verify-secret"
    ENV["WHATSAPP_APP_SECRET"] = "app-secret"
    ENV["WHATSAPP_PHONE_NUMBER_ID"] = "1234567890"
  end

  teardown do
    @saved_env.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
  end

  test "answers Meta's webhook verification challenge" do
    get "/webhooks/whatsapp", params: {
      "hub.mode" => "subscribe",
      "hub.verify_token" => "verify-secret",
      "hub.challenge" => "challenge-123"
    }

    assert_response :ok
    assert_equal "challenge-123", response.body
  end

  test "rejects webhook requests without a valid Meta signature" do
    post "/webhooks/whatsapp", params: "{}", headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :unauthorized
    assert_empty InboundMessage.all
  end

  test "stores an inbound message once and queues asynchronous processing" do
    body = webhook_payload.to_json
    headers = signed_headers(body)

    assert_enqueued_with(job: Whatsapp::ProcessInboundJob) do
      post "/webhooks/whatsapp", params: body, headers: headers
    end

    assert_response :ok
    inbound = InboundMessage.find_by!(provider_message_id: "wamid.central.1")
    assert_nil inbound.salon
    assert_equal "254700000000", inbound.sender_id
    assert_equal "BOOK BLADE1", inbound.payload.dig("message", "text", "body")

    assert_no_enqueued_jobs only: Whatsapp::ProcessInboundJob do
      post "/webhooks/whatsapp", params: body, headers: headers
    end
    assert_equal 1, InboundMessage.where(provider_message_id: "wamid.central.1").count
  end

  private

  def signed_headers(body)
    signature = OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("WHATSAPP_APP_SECRET"), body)
    { "CONTENT_TYPE" => "application/json", "X-Hub-Signature-256" => "sha256=#{signature}" }
  end

  def webhook_payload
    {
      "entry" => [ {
        "changes" => [ {
          "value" => {
            "metadata" => { "phone_number_id" => "1234567890" },
            "contacts" => [ { "wa_id" => "254700000000", "profile" => { "name" => "Sam" } } ],
            "messages" => [ {
              "id" => "wamid.central.1",
              "from" => "254700000000",
              "timestamp" => Time.current.to_i.to_s,
              "type" => "text",
              "text" => { "body" => "BOOK BLADE1" }
            } ]
          }
        } ]
      } ]
    }
  end
end
