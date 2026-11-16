class Customer < ApplicationRecord
  belongs_to :salon
  has_many :bookings, dependent: :restrict_with_exception
  has_one :conversation, dependent: :restrict_with_exception
  validates :whatsapp_sender_id, presence: true, uniqueness: { scope: :salon_id }
  validates :display_name, length: { maximum: 80 }
  validates :phone_e164, format: { with: /\A\+[1-9]\d{1,14}\z/ }, allow_blank: true
end
