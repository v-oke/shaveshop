module Notifications
  class Enqueue
    QUEUE_UPDATE_EVENTS = %w[customer_arrived service_started service_completed].freeze

    def initialize(event:)
      @event = event
    end

    def call
      booking = event.booking
      customer = booking.customer
      return unless customer

      dedupe_key = "booking-event-#{event.id}-customer-#{customer.id}"
      notification = Notification.create_or_find_by!(dedupe_key: dedupe_key) do |record|
        record.assign_attributes(
          salon: event.salon,
          booking: booking,
          event: event,
          kind: "whatsapp",
          milestone: event.event_type,
          content_snapshot: content_for(booking),
          status: suppressed?(customer) ? :suppressed : :queued
        )
      end
      if notification.queued?
        notification_id = notification.id
        ActiveRecord.after_all_transactions_commit do
          DeliverJob.perform_later(notification_id)
        end
      end
      notification
    end

    private

    attr_reader :event

    def suppressed?(customer)
      QUEUE_UPDATE_EVENTS.include?(event.event_type) && !customer.queue_updates_enabled?
    end

    def content_for(booking)
      local_start = booking.scheduled_start_at.in_time_zone(booking.salon.timezone)
      case event.event_type
      when "booking_created"
        "Booking confirmed: #{booking.service.name} with #{booking.staff.name} on " \
          "#{local_start.strftime('%a, %d %b at %I:%M %p')}. Reference: #{booking.reference}."
      when "customer_arrived"
        "You are checked in for #{booking.service.name}. Your place is based on your scheduled time."
      when "service_started"
        "Your #{booking.service.name} service has started."
      when "service_completed"
        "Your #{booking.service.name} service is complete. Thank you for visiting #{booking.salon.name}."
      else
        raise ArgumentError, "unsupported notification event: #{event.event_type}"
      end
    end
  end
end
