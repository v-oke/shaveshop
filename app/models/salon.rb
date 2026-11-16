class Salon < ApplicationRecord
  has_many :staff, dependent: :restrict_with_exception
  has_many :services, dependent: :restrict_with_exception
  has_many :opening_hours, dependent: :restrict_with_exception
  has_many :staff_availabilities, dependent: :restrict_with_exception
  has_many :customers, dependent: :restrict_with_exception
  has_many :bookings, dependent: :restrict_with_exception
  has_many :conversations, dependent: :restrict_with_exception
  has_many :booking_events, dependent: :restrict_with_exception
  has_many :inbound_messages, dependent: :restrict_with_exception
  has_many :notifications, dependent: :restrict_with_exception
  validates :name, :timezone, :currency, :whatsapp_phone_number_id, presence: true
  validates :whatsapp_phone_number_id, uniqueness: true
  validates :booking_horizon_days, :slot_step_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :grace_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate do
    errors.add(:timezone, "is invalid") unless ActiveSupport::TimeZone[timezone]
  end
end
