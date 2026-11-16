module Bookings
  class Queue
    Snapshot = Struct.new(:in_progress, :waiting, :upcoming, keyword_init: true) do
      def first_waiting
        waiting.first
      end

      def position_for(booking)
        index = waiting.index { |queued_booking| queued_booking.id == booking.id }
        index && index + 1
      end
    end

    def initialize(salon:, staff:, date: Time.current.in_time_zone(salon.timezone).to_date)
      @salon = salon
      @staff = staff
      @date = date
      raise ArgumentError, "date must be a Date" unless date.instance_of?(Date)
      raise ArgumentError, "staff must belong to the salon" unless staff.salon_id == salon.id
    end

    def call
      bookings = salon.bookings.where(staff: staff, service_date: date)
      Snapshot.new(
        in_progress: bookings.find_by(status: :in_progress),
        waiting: bookings.where(status: :waiting).order(:scheduled_start_at, :id).to_a,
        upcoming: bookings.where(status: :confirmed).order(:scheduled_start_at, :id).to_a
      )
    end

    private

    attr_reader :salon, :staff, :date
  end
end
