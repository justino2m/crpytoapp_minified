class Fifo < BaseCalculator
  def fetch_deposits(withdrawal)
    BatchLoad.call(base_deposits_query(withdrawal).ordered, 10, &Proc.new)
  end
end