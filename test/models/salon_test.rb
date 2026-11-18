require "test_helper"

class SalonTest < ActiveSupport::TestCase
  setup do
    @previous_number = ENV["WHATSAPP_BUSINESS_NUMBER"]
    ENV["WHATSAPP_BUSINESS_NUMBER"] = "254700000000"
  end

  teardown do
    ENV["WHATSAPP_BUSINESS_NUMBER"] = @previous_number
  end

  test "assigns a unique public booking code when one is omitted" do
    salon = Salon.create!(name: "Blade")

    assert_match(/\A[A-Z0-9]{6}\z/, salon.booking_code)
  end

  test "builds a WhatsApp click to chat link with the salon code" do
    salon = Salon.create!(name: "Blade", booking_code: "blade1")

    assert_equal "BLADE1", salon.booking_code
    assert_equal "https://wa.me/254700000000?text=BOOK%20BLADE1", salon.booking_link
  end

  test "generates a standalone SVG QR code for the booking link" do
    salon = Salon.create!(name: "Blade", booking_code: "BLADE1")

    assert_match(/<svg/, salon.booking_qr_svg)
    assert_includes salon.booking_qr_svg, "<path"
  end

  test "booking link is unavailable until the platform number is configured" do
    ENV.delete("WHATSAPP_BUSINESS_NUMBER")
    salon = Salon.create!(name: "Blade", booking_code: "BLADE1")

    assert_nil salon.booking_link
    assert_nil salon.booking_qr_svg
  end
end
