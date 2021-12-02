class LowestCost < BaseCalculator
  def fetch_deposits(withdrawal)
    BatchLoad.call(base_deposits_query(withdrawal).order(value: :asc), 10, &Proc.new)
  end
end
