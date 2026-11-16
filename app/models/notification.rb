class Notification < ApplicationRecord
  include SalonOwnership
  belongs_to :salon
  belongs_to :booking
  belongs_to :event, class_name: "BookingEvent"
  same_salon_as :booking, :event
  enum :status, %w[queued sending accepted delivered failed suppressed].index_with(&:itself), validate: true
  validates :kind, :dedupe_key, :content_snapshot, presence: true
  validates :dedupe_key, uniqueness: true
  validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate do
    errors.add(:event, "must belong to the booking") if event && booking && event.booking != booking
  end
end
