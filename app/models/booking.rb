class Booking < ApplicationRecord
  include SalonOwnership
  belongs_to :salon
  belongs_to :customer, optional: true
  belongs_to :staff
  belongs_to :service
  has_many :booking_events, dependent: :restrict_with_exception
  has_many :notifications, dependent: :restrict_with_exception
  same_salon_as :customer, :staff, :service
  enum :status, %w[confirmed waiting in_progress completed cancelled no_show].index_with(&:itself), validate: true
  enum :source, { whatsapp: "whatsapp", walk_in: "walk_in" }, validate: true
  scope :active, -> { where(status: %w[confirmed waiting in_progress]) }
  validates :customer_name_snapshot, :reference, :scheduled_start_at, :scheduled_end_at, :service_date, presence: true
  validates :customer_name_snapshot, length: { maximum: 80 }
  validates :reference, uniqueness: { scope: :salon_id }
  validates :price_minor_snapshot, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :duration_snapshot, numericality: { only_integer: true, greater_than: 0 }
  validates :customer, presence: true, if: :whatsapp?
  before_validation :set_service_date
  validate do
    if scheduled_start_at && scheduled_end_at && duration_snapshot
      errors.add(:scheduled_end_at, "must match the duration snapshot") unless scheduled_end_at == scheduled_start_at + duration_snapshot.minutes
    end
  end

  private

  def set_service_date
    self.service_date = scheduled_start_at.in_time_zone(salon.timezone).to_date if scheduled_start_at && salon && ActiveSupport::TimeZone[salon.timezone]
  end
end
