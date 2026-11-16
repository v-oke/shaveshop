class Service < ApplicationRecord
  belongs_to :salon
  has_many :bookings, dependent: :restrict_with_exception
  validates :name, presence: true
  validates :price_minor, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :duration_minutes, numericality: { only_integer: true, greater_than: 0 }
end
