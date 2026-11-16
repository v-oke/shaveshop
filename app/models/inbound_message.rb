class InboundMessage < ApplicationRecord
  belongs_to :salon
  validates :provider_message_id, presence: true, uniqueness: true
  validates :sender_id, :received_at, presence: true
  enum :processing_status, %w[pending processing processed failed].index_with(&:itself), validate: true
end
