class Snapshot < ApplicationRecord
  belongs_to :user
  serialize :worths, HashSerializer
end
