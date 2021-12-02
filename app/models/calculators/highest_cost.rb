class HighestCost < BaseCalculator
  def fetch_deposits(investment)
    super.order(value: :desc)
  end
end
