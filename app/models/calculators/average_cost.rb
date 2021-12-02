class AverageCost < BaseCalculator
  AVERAGE_COST_POOL = 'average_cost_pool'.freeze

  # acb doent have any indirect investments
  def dependent_investment_ids(investments)
    []
  end

  def fetch_deposits(withdrawal)
    # acb needs all previous investments, not just 'extractable' ones so cant use base_query. we
    # also need to pass full query instead of individual investments
    yield(current_user.investments.where(cost_basis_pool(withdrawal)).earlier_than(withdrawal), AVERAGE_COST_POOL)
  end

  def extract_value_from(q, ideal_amount, pool_name)
    if q.is_a?(Hash) # shared pool passes separate queries for deposits and withdrawals
      deposits = q[:deposits]
      withdrawals = q[:withdrawals]
    else
      deposits = q.deposits
      withdrawals = q.withdrawals
    end

    # note: total_withdrawn_amount can be more than total_deposited_amount when dealing with negative balances
    total_deposited_value, total_deposited_amount = deposits.pluck(Arel.sql('sum(value)'), Arel.sql('sum(amount)')).first
    total_withdrawn_value, total_withdrawn_amount = withdrawals.pluck(Arel.sql('sum(value)'), Arel.sql('abs(sum(amount))')).first

    # we get nil if no rows
    total_deposited_value ||= 0
    total_deposited_amount ||= 0
    total_withdrawn_value ||= 0
    total_withdrawn_amount ||= 0

    # prefer 0 over negative sums
    remaining_value = [0, total_deposited_value - total_withdrawn_value].max
    remaining_amount = [0, total_deposited_amount - total_withdrawn_amount].max

    average_cost = remaining_value.to_d / remaining_amount.to_d
    average_cost = 0 if average_cost.nan? || average_cost.infinite?
    ideal_value = ideal_amount * average_cost

    # do not extract more than is available
    adjusted_value = ideal_value > remaining_value ? remaining_value : ideal_value
    adjusted_amount = ideal_amount > remaining_amount ? remaining_amount : ideal_amount

    build_extraction(nil, adjusted_amount, adjusted_value, pool_name) unless adjusted_amount.zero? && adjusted_value.zero?
  end
end
