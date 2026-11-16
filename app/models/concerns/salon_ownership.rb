module SalonOwnership
  extend ActiveSupport::Concern

  class_methods do
    def same_salon_as(*associations)
      validate do
        associations.each do |name|
          record = public_send(name)
          errors.add(name, "must belong to the same salon") if record && record.salon != salon
        end
      end
    end
  end
end
