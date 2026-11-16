class OpeningHour < ApplicationRecord
  belongs_to :salon
  validates :weekday, inclusion: { in: 0..6 }, uniqueness: { scope: :salon_id }
  validates :opens_at_local, :closes_at_local, presence: true
  validate do
    errors.add(:closes_at_local, "must be after opening") if opens_at_local && closes_at_local && closes_at_local <= opens_at_local
  end
end
