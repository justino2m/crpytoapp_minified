class ChangeMinedLabelToMiningOnTransactions < ActiveRecord::Migration[5.2]
  def change
    Transaction.where(label: 'mined').update_all(label: 'mining')
    Transaction.where(label: 'income').update_all(label: 'other_income')
  end
end
