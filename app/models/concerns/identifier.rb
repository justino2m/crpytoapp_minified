module Identifier
  extend ActiveSupport::Concern

  included do
    validates_uniqueness_of :identifier
    before_save -> { self.identifier.upcase! }
  end
end
