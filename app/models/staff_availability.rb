class StaffAvailability < ApplicationRecord
  include SalonOwnership
  belongs_to :salon
  belongs_to :staff
  same_salon_as :staff
  validates :local_date, :starts_at, :ends_at, presence: true
  validate do
    errors.add(:ends_at, "must be after start") if starts_at && ends_at && ends_at <= starts_at
  end
end
