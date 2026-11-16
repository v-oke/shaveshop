module Bookings
  class Transition
    class InvalidTransition < StandardError; end

    TRANSITIONS = {
      arrival: { from: "confirmed", to: "waiting", timestamp: :arrived_at, event: "customer_arrived" },
      start: { from: "waiting", to: "in_progress", timestamp: :started_at, event: "service_started" },
      completion: { from: "in_progress", to: "completed", timestamp: :completed_at, event: "service_completed" }
    }.freeze

    def initialize(booking:, action:, actor_staff: nil, now: Time.current)
      @booking = booking
      @action = action.to_sym
      @actor_staff = actor_staff
      @now = now
    end

    def call
      transition = TRANSITIONS[action]
      raise ArgumentError, "action must be arrival, start, or completion" unless transition
      if actor_staff && actor_staff.salon_id != booking.salon_id
        raise ArgumentError, "actor must belong to the booking's salon"
      end

      booking.with_lock do
        unless booking.status == transition[:from]
          raise InvalidTransition, "Cannot #{action} a booking with status #{booking.status}"
        end

        validate_timing!(transition)
        if action == :start
          booking.staff.lock!
          queue = Queue.new(salon: booking.salon, staff: booking.staff, date: booking.service_date).call
          unless queue.first_waiting&.id == booking.id
            raise InvalidTransition, "Only the next waiting customer can start service"
          end
        end

        booking.update!(status: transition[:to], transition[:timestamp] => now)
        event = booking.salon.booking_events.create!(
          booking: booking,
          actor_staff: actor_staff,
          event_type: transition[:event],
          occurred_at: now,
          metadata_json: { "from" => transition[:from], "to" => transition[:to] }
        )
        Notifications::Enqueue.new(event: event).call
        booking
      end
    rescue ActiveRecord::RecordNotUnique => error
      raise unless action == :start && one_service_per_staff_conflict?(error)

      raise InvalidTransition, "This staff member is already serving a customer"
    end

    private

    attr_reader :booking, :action, :actor_staff, :now

    def validate_timing!(transition)
      unless now.is_a?(Time) || now.is_a?(ActiveSupport::TimeWithZone)
        raise ArgumentError, "now must be a time"
      end

      if action == :start && now < booking.scheduled_start_at
        raise InvalidTransition, "Cannot start a service before its scheduled time"
      end

      if action == :completion && booking.started_at && now < booking.started_at
        raise InvalidTransition, "Completion time cannot be before service start"
      end
    end

    def one_service_per_staff_conflict?(error)
      error.cause.is_a?(PG::UniqueViolation) && error.cause.message.include?("one_service_per_barber")
    end
  end
end
