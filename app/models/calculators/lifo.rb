class Lifo < BaseCalculator
  def fetch_deposits(withdrawal)
    BatchLoad.call(base_deposits_query(withdrawal).reverse_ordered, 10, &Proc.new)
  end
end