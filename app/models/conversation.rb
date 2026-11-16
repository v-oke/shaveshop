class Conversation < ApplicationRecord
  include SalonOwnership
  belongs_to :salon
  belongs_to :customer
  same_salon_as :customer
  enum :state, %w[idle choosing_service choosing_date choosing_slot collecting_name reviewing booked cancelling].index_with(&:itself), validate: true
  validates :customer_id, uniqueness: { scope: :salon_id }
end
