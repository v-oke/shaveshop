require "test_helper"

class Bookings::CreateTest < ActiveSupport::TestCase
  setup do
    @salon = Salon.create!(name: "Blade", booking_code: "BLADE1")
    @staff = @salon.staff.create!(name: "David", email: "david@example.com", password: "password123", role: :barber)
    @service = @salon.services.create!(name: "Haircut", price_minor: 50_000, duration_minutes: 30)
    @customer = @salon.customers.create!(whatsapp_sender_id: "sender-1", display_name: "Sam")
    @date = Date.current + 2
    zone = Time.find_zone!(@salon.timezone)
    @now = zone.local(@date.year, @date.month, @date.day, 7)
    @starts_at = zone.local(@date.year, @date.month, @date.day, 9)

    @salon.opening_hours.create!(
      weekday: @date.wday,
      opens_at_local: Time.utc(2000, 1, 1, 9),
      closes_at_local: Time.utc(2000, 1, 1, 12)
    )
    @staff.staff_availabilities.create!(
      salon: @salon,
      local_date: @date,
      starts_at: @starts_at,
      ends_at: @starts_at + 3.hours
    )
  end

  test "creates a confirmed booking with snapshots and a creation event" do
    booking = creator.call

    assert_equal "confirmed", booking.status
    assert_equal @customer, booking.customer
    assert_equal @staff, booking.staff
    assert_equal "Sam", booking.customer_name_snapshot
    assert_equal @starts_at, booking.scheduled_start_at
    assert_equal @starts_at + 30.minutes, booking.scheduled_end_at
    assert_equal 50_000, booking.price_minor_snapshot
    assert_equal 30, booking.duration_snapshot
    assert_match(/\ABB[A-Z0-9]{8}\z/, booking.reference)
    assert_equal ["booking_created"], booking.booking_events.pluck(:event_type)
  end

  test "rechecks availability and refuses a slot claimed before confirmation" do
    @staff.bookings.create!(
      salon: @salon,
      service: @service,
      customer_name_snapshot: "Walk-in",
      source: :walk_in,
      reference: "EXISTING",
      scheduled_start_at: @starts_at,
      scheduled_end_at: @starts_at + 30.minutes,
      price_minor_snapshot: 50_000,
      duration_snapshot: 30
    )

    assert_raises(Bookings::Create::SlotUnavailable) { creator.call }
    assert_equal 1, @salon.bookings.count
    assert_empty @salon.booking_events
  end

  test "rejects a customer from another salon" do
    other_salon = Salon.create!(name: "Other", booking_code: "OTHER1")
    other_customer = other_salon.customers.create!(whatsapp_sender_id: "sender-2")

    assert_raises(ArgumentError) do
      Bookings::Create.new(
        salon: @salon, customer: other_customer, service: @service,
        staff: @staff, starts_at: @starts_at, now: @now
      ).call
    end
  end

  private

  def creator
    Bookings::Create.new(
      salon: @salon,
      customer: @customer,
      service: @service,
      staff: @staff,
      starts_at: @starts_at,
      now: @now
    )
  end
end
