class WhatsappContact < ApplicationRecord
  belongs_to :active_salon, class_name: "Salon", optional: true
  belongs_to :pending_salon, class_name: "Salon", optional: true

  enum :state, %w[awaiting_salon choosing_previous_salon choosing_another_salon active].index_with(&:itself), validate: true
  validates :sender_id, presence: true, uniqueness: true, format: { with: /\A\d{7,20}\z/ }
  validate do
    errors.add(:active_salon, "is required for an active contact") if active? && active_salon.nil?
    errors.add(:pending_salon, "is required while choosing a previous salon") if choosing_previous_salon? && pending_salon.nil?
  end
end
