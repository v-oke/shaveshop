require "test_helper"

class Availability::SlotFinderTest < ActiveSupport::TestCase
  setup do
    @salon = Salon.create!(name: "Blade", booking_code: "BLADE1")
    @staff = @salon.staff.create!(name: "David", email: "david@example.com", password: "password123", role: :barber)
    @service = @salon.services.create!(name: "Haircut", price_minor: 50_000, duration_minutes: 30)
    @date = Date.new(2026, 10, 6)
    @now = Time.utc(2026, 10, 6, 5)

    @salon.opening_hours.create!(
      weekday: @date.wday,
      opens_at_local: Time.utc(2000, 1, 1, 9),
      closes_at_local: Time.utc(2000, 1, 1, 11)
    )
    @staff.staff_availabilities.create!(
      salon: @salon,
      local_date: @date,
      starts_at: Time.utc(2026, 10, 6, 6),
      ends_at: Time.utc(2026, 10, 6, 8)
    )
  end

  test "returns grid-aligned slots within opening hours and staff availability" do
    slots = finder.call

    assert_equal 7, slots.length
    assert_equal Time.utc(2026, 10, 6, 6), slots.first.starts_at
    assert_equal Time.utc(2026, 10, 6, 7, 30), slots.last.starts_at
    assert slots.all? { |slot| slot.staff == @staff && slot.ends_at - slot.starts_at == 30.minutes }
  end

  test "excludes past slots and slots overlapping active bookings" do
    @staff.bookings.create!(
      salon: @salon,
      service: @service,
      customer_name_snapshot: "Walk-in",
      source: :walk_in,
      reference: "BB1",
      scheduled_start_at: Time.utc(2026, 10, 6, 6, 30),
      scheduled_end_at: Time.utc(2026, 10, 6, 7),
      price_minor_snapshot: 50_000,
      duration_snapshot: 30
    )

    slots = Availability::SlotFinder.new(
      salon: @salon, service: @service, date: @date,
      staff: @staff, now: Time.utc(2026, 10, 6, 6, 15)
    ).call

    assert_equal [
      Time.utc(2026, 10, 6, 7),
      Time.utc(2026, 10, 6, 7, 15),
      Time.utc(2026, 10, 6, 7, 30)
    ], slots.map(&:starts_at)
  end

  test "requires a staff availability interval that contains the full slot" do
    @staff.staff_availabilities.update_all(ends_at: Time.utc(2026, 10, 6, 6, 45))

    assert_equal [
      Time.utc(2026, 10, 6, 6),
      Time.utc(2026, 10, 6, 6, 15)
    ], finder.call.map(&:starts_at)
  end

  test "returns no slots outside the salon booking horizon or on a closed day" do
    beyond_horizon = @date + @salon.booking_horizon_days + 1
    closed_date = @date + 1

    assert_empty finder(date: beyond_horizon).call
    assert_empty finder(date: closed_date).call
  end

  test "rejects a service from another salon" do
    other_salon = Salon.create!(name: "Other", booking_code: "OTHER1")
    other_service = other_salon.services.create!(name: "Trim", price_minor: 10_000, duration_minutes: 15)

    assert_raises(ArgumentError) do
      Availability::SlotFinder.new(salon: @salon, service: other_service, date: @date)
    end
  end

  private

  def finder(date: @date)
    Availability::SlotFinder.new(salon: @salon, service: @service, date: date, now: @now)
  end
end
