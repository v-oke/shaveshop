class Staff < ApplicationRecord
  belongs_to :salon
  has_secure_password
  has_many :bookings, dependent: :restrict_with_exception
  has_many :staff_availabilities, dependent: :restrict_with_exception
  enum :role, { owner: "owner", barber: "barber" }, validate: true
  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :name, :email, presence: true
  validates :email, uniqueness: { scope: :salon_id }
end
