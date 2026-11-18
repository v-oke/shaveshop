module Whatsapp
  class ProcessInboundJob < ApplicationJob
    queue_as :whatsapp_inbound

    PROCESSING_LEASE = 2.minutes

    retry_on Whatsapp::CloudApi::Error, wait: :polynomially_longer, attempts: 5 do |job, _error|
      InboundMessage.find_by(id: job.arguments.first)&.update!(processing_status: :failed)
    end

    def perform(inbound_message_id)
      inbound = InboundMessage.find_by(id: inbound_message_id)
      return unless inbound

      result = inbound.with_lock do
        if inbound.processed? || inbound.failed?
          :skip
        elsif inbound.processing? && inbound.updated_at > PROCESSING_LEASE.ago
          [ :busy, inbound.updated_at + PROCESSING_LEASE ]
        else
          reply = if inbound.payload.key?("outbound_response")
            inbound.payload["outbound_response"]
          else
            router = SalonRouter.new(inbound_message: inbound)
            response = router.call
            inbound.update!(salon: router.salon, payload: inbound.payload.merge("outbound_response" => response))
            response
          end
          inbound.update!(processing_status: :processing)
          [ :ready, reply ]
        end
      end

      return if result == :skip
      if result.first == :busy
        self.class.set(wait_until: result.second).perform_later(inbound.id)
        return
      end

      ReplyDelivery.new(recipient: inbound.sender_id, reply: result.second).call
      inbound.update!(processing_status: :processed)
    rescue Whatsapp::CloudApi::Error => error
      inbound&.update!(processing_status: error.retryable ? :pending : :failed)
      raise if error.retryable

      Rails.logger.warn("WhatsApp inbound reply failed permanently for message #{inbound&.id}")
    rescue StandardError => error
      inbound&.update!(processing_status: :failed)
      Rails.logger.error("WhatsApp inbound processing failed for message #{inbound&.id}: #{error.class}")
      raise
    end
  end
end
