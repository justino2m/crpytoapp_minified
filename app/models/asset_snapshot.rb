class AssetSnapshot < ApplicationRecord
  belongs_to :user
  belongs_to :asset
  belongs_to :currency
  validates_presence_of :date
  validates_numericality_of :total_amount, :total_worth, :invested_value
end
