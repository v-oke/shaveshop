module Bookings
  class Create
    class SlotUnavailable < StandardError; end

    def initialize(salon:, customer:, service:, starts_at:, staff: nil, customer_name: nil, source: :whatsapp, now: Time.current)
      @salon = salon
      @customer = customer
      @service = service
      @starts_at = starts_at
      @staff = staff
      @customer_name = customer_name.presence || customer&.display_name.presence || customer&.phone_e164.presence
      @source = source.to_sym
      @now = now
    end

    def call
      validate_inputs!

      Booking.transaction do
        # Serialize slot claims for this barber. The database exclusion constraint
        # remains the final guard if another booking path does not take this lock.
        staff.lock!

        slot = available_slot
        raise SlotUnavailable, "The selected slot is no longer available" unless slot

        booking = salon.bookings.create!(
          customer: customer,
          staff: slot.staff,
          service: service,
          customer_name_snapshot: customer_name,
          source: source,
          reference: generate_reference,
          scheduled_start_at: slot.starts_at,
          scheduled_end_at: slot.ends_at,
          price_minor_snapshot: service.price_minor,
          duration_snapshot: service.duration_minutes,
          status: :confirmed
        )

        event = salon.booking_events.create!(
          booking: booking,
          event_type: "booking_created",
          occurred_at: now,
          metadata_json: {
            "source" => source.to_s,
            "service_name" => service.name,
            "staff_name" => slot.staff.name
          }
        )
        Notifications::Enqueue.new(event: event).call

        booking
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
      raise unless database_booking_conflict?(error)

      raise SlotUnavailable, "The selected slot is no longer available"
    end

    private

    attr_reader :salon, :customer, :service, :starts_at, :staff, :customer_name, :source, :now

    def validate_inputs!
      raise ArgumentError, "customer must belong to the salon" if customer && customer.salon_id != salon.id
      raise ArgumentError, "service must belong to the salon" unless service.salon_id == salon.id
      raise ArgumentError, "service must be active" unless service.active?
      raise ArgumentError, "staff is required" unless staff
      raise ArgumentError, "staff must belong to the salon" if staff && staff.salon_id != salon.id
      raise ArgumentError, "staff must be active" if staff && !staff.active?
      raise ArgumentError, "WhatsApp bookings require a customer" if source == :whatsapp && customer.nil?
      raise ArgumentError, "customer name is required" if customer_name.blank?
      raise ArgumentError, "starts_at must be a Time" unless starts_at.is_a?(Time)
      raise ArgumentError, "source must be whatsapp or walk_in" unless %i[whatsapp walk_in].include?(source)
    end

    def available_slot
      local_date = starts_at.in_time_zone(salon.timezone).to_date
      Availability::SlotFinder.new(
        salon: salon,
        service: service,
        date: local_date,
        staff: staff,
        now: now
      ).call.find { |slot| slot.starts_at == starts_at }
    end

    def generate_reference
      loop do
        reference = "BB#{SecureRandom.alphanumeric(8).upcase}"
        break reference unless salon.bookings.exists?(reference: reference)
      end
    end

    def database_booking_conflict?(error)
      error.cause.is_a?(PG::ExclusionViolation) ||
        error.cause.is_a?(PG::UniqueViolation) && error.cause.message.include?("one_active_customer_booking_per_day")
    end
  end
end
