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
  has_many :active_whatsapp_contacts, class_name: "WhatsappContact", foreign_key: :active_salon_id, dependent: :nullify
  has_many :pending_whatsapp_contacts, class_name: "WhatsappContact", foreign_key: :pending_salon_id, dependent: :nullify
  normalizes :booking_code, with: ->(code) { code.strip.upcase }
  validates :name, :timezone, :currency, :booking_code, presence: true
  validates :booking_code, uniqueness: { case_sensitive: false }, format: { with: /\A[A-Z0-9]{4,12}\z/ }
  validates :booking_horizon_days, :slot_step_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :grace_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  before_validation :assign_booking_code, on: :create
  validate do
    errors.add(:timezone, "is invalid") unless ActiveSupport::TimeZone[timezone]
  end

  def booking_link
    number = ENV["WHATSAPP_BUSINESS_NUMBER"].to_s.gsub(/\D/, "")
    return if number.blank? || booking_code.blank?

    encoded_message = ERB::Util.url_encode("BOOK #{booking_code}").tr("+", "%20")
    "https://wa.me/#{number}?text=#{encoded_message}"
  end

  def booking_qr_svg
    return if booking_link.blank?

    RQRCode::QRCode.new(booking_link).as_svg(module_size: 6, standalone: true, use_path: true)
  end

  private

  def assign_booking_code
    return if booking_code.present?

    loop do
      self.booking_code = SecureRandom.alphanumeric(6).upcase
      break unless self.class.exists?(booking_code: booking_code)
    end
  end
end
