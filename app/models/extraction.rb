class Extraction < ApplicationRecord
  belongs_to :user
  belongs_to :from_investment, class_name: Investment.to_s, inverse_of: :from_extractions, optional: true
  belongs_to :to_investment, class_name: Investment.to_s, inverse_of: :to_extractions
  validates_numericality_of :amount, :value
end
