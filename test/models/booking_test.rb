require "test_helper"

class BookingTest < ActiveSupport::TestCase
  setup do
    @salon = Salon.create!(name: "Blade", whatsapp_phone_number_id: "phone-1")
    @staff = @salon.staff.create!(name: "David", email: "david@example.com", password: "password123", role: :barber)
    @service = @salon.services.create!(name: "Haircut", price_minor: 50_000, duration_minutes: 30)
    @customer = @salon.customers.create!(whatsapp_sender_id: "sender-1")
  end

  def booking_attributes
    { salon: @salon, staff: @staff, service: @service, customer: @customer,
      customer_name_snapshot: "Customer", source: :whatsapp, reference: "BB1",
      scheduled_start_at: Time.utc(2026, 10, 6, 11), scheduled_end_at: Time.utc(2026, 10, 6, 11, 30),
      price_minor_snapshot: 50_000, duration_snapshot: 30 }
  end

  test "derives local date and retains snapshots when service changes" do
    booking = Booking.create!(booking_attributes)
    assert_equal Date.new(2026, 10, 6), booking.service_date
    @service.update!(price_minor: 60_000, duration_minutes: 45)
    assert_equal 50_000, booking.reload.price_minor_snapshot
    assert_equal 30, booking.duration_snapshot
  end

  test "rejects cross salon associations at model and database levels" do
    other = Salon.create!(name: "Other", whatsapp_phone_number_id: "phone-2")
    customer = other.customers.create!(whatsapp_sender_id: "sender-2")
    booking = Booking.new(booking_attributes.merge(customer: customer))
    assert_not booking.valid?
    assert_includes booking.errors[:customer], "must belong to the same salon"
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Booking.transaction(requires_new: true) { booking.save!(validate: false) }
    end
  end

  test "database rejects overlaps but permits adjacent reservations" do
    Booking.create!(booking_attributes)
    attrs = booking_attributes.merge(reference: "BB2", source: :walk_in, customer: nil,
      scheduled_start_at: Time.utc(2026, 10, 6, 11, 15), scheduled_end_at: Time.utc(2026, 10, 6, 11, 45))
    assert_raises(ActiveRecord::StatementInvalid) do
      Booking.transaction(requires_new: true) { Booking.create!(attrs) }
    end
    attrs.merge!(scheduled_start_at: Time.utc(2026, 10, 6, 11, 30), scheduled_end_at: Time.utc(2026, 10, 6, 12))
    assert Booking.create!(attrs).persisted?
  end

  test "database limits customer to one active booking per local day" do
    Booking.create!(booking_attributes)
    attrs = booking_attributes.merge(reference: "BB2", scheduled_start_at: Time.utc(2026, 10, 6, 12), scheduled_end_at: Time.utc(2026, 10, 6, 12, 30))
    assert_raises(ActiveRecord::RecordNotUnique) do
      Booking.transaction(requires_new: true) { Booking.create!(attrs) }
    end
    @salon.bookings.first.update!(status: :cancelled)
    assert Booking.create!(attrs).persisted?
  end

  test "database permits only one in progress booking per barber" do
    Booking.create!(booking_attributes.merge(status: :in_progress))
    attrs = booking_attributes.merge(reference: "BB2", customer: nil, source: :walk_in, status: :in_progress,
      scheduled_start_at: Time.utc(2026, 10, 6, 12), scheduled_end_at: Time.utc(2026, 10, 6, 12, 30))
    assert_raises(ActiveRecord::RecordNotUnique) do
      Booking.transaction(requires_new: true) { Booking.create!(attrs) }
    end
  end
end
