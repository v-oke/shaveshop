class BookingEvent < ApplicationRecord
  include SalonOwnership
  belongs_to :salon
  belongs_to :booking
  belongs_to :actor_staff, class_name: "Staff", optional: true
  same_salon_as :booking, :actor_staff
  has_many :notifications, foreign_key: :event_id, dependent: :restrict_with_exception
  validates :event_type, :occurred_at, presence: true
end
