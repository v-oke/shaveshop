module Notifications
  class DeliverJob < ApplicationJob
    queue_as :notifications

    MAX_ATTEMPTS = 5
    RETRY_DELAYS = [ 1.minute, 5.minutes, 15.minutes, 1.hour ].freeze
    SENDING_LEASE = 2.minutes
    CUSTOMER_SERVICE_WINDOW = 24.hours

    def perform(notification_id)
      notification = Notification.find_by(id: notification_id)
      return unless notification

      claim = claim_notification(notification)
      return unless claim
      unless claim == true
        self.class.set(wait_until: claim).perform_later(notification.id)
        return
      end

      self.class.set(wait_until: SENDING_LEASE.from_now).perform_later(notification.id)
      message_id = deliver(notification)
      notification.with_lock do
        if notification.sending?
          notification.update!(status: :accepted, provider_message_id: message_id, last_error: nil)
        end
      end
    rescue Whatsapp::CloudApi::Error => error
      record_failure(notification, error) if notification
    end

    private

    def claim_notification(notification)
      notification.with_lock do
        if notification.queued?
          if notification.next_attempt_at&.future?
            notification.next_attempt_at
          else
            notification.update!(status: :sending, attempts: notification.attempts + 1, next_attempt_at: nil)
            :claimed
          end
        elsif notification.sending?
          if notification.updated_at <= SENDING_LEASE.ago
            notification.update!(status: :queued)
            Time.current
          else
            notification.updated_at + SENDING_LEASE
          end
        end
      end.then { |result| result == :claimed ? true : result }
    end

    def deliver(notification)
      booking = notification.booking
      customer = booking.customer
      unless customer
        notification.update!(status: :suppressed, last_error: "Booking has no customer recipient")
        return
      end

      client = Whatsapp::CloudApi.new
      conversation = customer.conversation
      if conversation&.last_inbound_at && conversation.last_inbound_at >= CUSTOMER_SERVICE_WINDOW.ago
        client.send_text(
          phone_number_id: ENV["WHATSAPP_PHONE_NUMBER_ID"],
          recipient: customer.whatsapp_sender_id,
          text: notification.content_snapshot
        )
      else
        template_name = ENV["WHATSAPP_UTILITY_TEMPLATE_NAME"]
        raise Whatsapp::CloudApi::Error, "Customer service window expired and no approved WhatsApp template is configured" if template_name.blank?

        client.send_template(
          phone_number_id: ENV["WHATSAPP_PHONE_NUMBER_ID"],
          recipient: customer.whatsapp_sender_id,
          name: template_name,
          language: ENV.fetch("WHATSAPP_TEMPLATE_LANGUAGE", "en"),
          body_parameter: notification.content_snapshot
        )
      end
    end

    def record_failure(notification, error)
      retry_at = nil
      notification.with_lock do
        return unless notification.sending?

        if error.retryable && notification.attempts < MAX_ATTEMPTS
          delay = RETRY_DELAYS.fetch([ notification.attempts - 1, RETRY_DELAYS.length - 1 ].min)
          retry_at = Time.current + delay
          notification.update!(status: :queued, next_attempt_at: retry_at, last_error: error.message.truncate(1_000))
        else
          notification.update!(status: :failed, next_attempt_at: nil, last_error: error.message.truncate(1_000))
        end
      end
      self.class.set(wait_until: retry_at).perform_later(notification.id) if retry_at
    end
  end
end
