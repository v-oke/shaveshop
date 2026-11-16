module Availability
  class SlotFinder
    Slot = Struct.new(:staff, :starts_at, :ends_at, keyword_init: true)

    def initialize(salon:, service:, date:, staff: nil, now: Time.current)
      @salon = salon
      @service = service
      @date = date
      @staff = staff
      @now = now

      raise ArgumentError, "date must be a Date" unless date.instance_of?(Date)
      raise ArgumentError, "service must belong to the salon" unless service.salon_id == salon.id
      raise ArgumentError, "service must be active" unless service.active?
      raise ArgumentError, "staff must belong to the salon" if staff && staff.salon_id != salon.id
    end

    def call
      return [] unless within_booking_horizon?

      opening_intervals = opening_intervals_for_date
      return [] if opening_intervals.empty?

      staff_members = salon.staff.where(active: true)
      staff_members = staff_members.where(id: staff.id) if staff

      staff_members.flat_map do |staff_member|
        availabilities = salon.staff_availabilities.where(staff: staff_member, local_date: date)
        next [] unless availabilities.exists?

        bookings = active_bookings_for(staff_member, opening_intervals)
        slots_for(staff_member, availabilities, bookings, opening_intervals)
      end
    end

    private

    attr_reader :salon, :service, :date, :staff, :now

    def within_booking_horizon?
      today = now.in_time_zone(salon.timezone).to_date
      date >= today && date <= today + salon.booking_horizon_days.days
    end

    def opening_intervals_for_date
      salon.opening_hours.where(weekday: date.wday).map do |hours|
        zone = ActiveSupport::TimeZone[salon.timezone]
        [
          zone.local(date.year, date.month, date.day, hours.opens_at_local.hour, hours.opens_at_local.min, hours.opens_at_local.sec),
          zone.local(date.year, date.month, date.day, hours.closes_at_local.hour, hours.closes_at_local.min, hours.closes_at_local.sec)
        ]
      end
    end

    def active_bookings_for(staff_member, opening_intervals)
      earliest_open = opening_intervals.map(&:first).min
      latest_close = opening_intervals.map(&:last).max

      salon.bookings.active.where(staff: staff_member)
        .where("scheduled_start_at < ? AND scheduled_end_at > ?", latest_close, earliest_open)
    end

    def slots_for(staff_member, availabilities, bookings, opening_intervals)
      opening_intervals.flat_map do |opens_at, closes_at|
        starts = []
        candidate_start = opens_at

        while candidate_start + service.duration_minutes.minutes <= closes_at
          candidate_end = candidate_start + service.duration_minutes.minutes
          available = candidate_start > now &&
            availabilities.any? { |availability| availability.starts_at <= candidate_start && availability.ends_at >= candidate_end }
          unbooked = bookings.none? do |booking|
            booking.scheduled_start_at < candidate_end && booking.scheduled_end_at > candidate_start
          end

          starts << Slot.new(staff: staff_member, starts_at: candidate_start, ends_at: candidate_end) if available && unbooked
          candidate_start += salon.slot_step_minutes.minutes
        end

        starts
      end
    end
  end
end
