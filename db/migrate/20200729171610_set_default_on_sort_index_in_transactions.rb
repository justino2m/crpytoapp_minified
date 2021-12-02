class SetDefaultOnSortIndexInTransactions < ActiveRecord::Migration[5.2]
  def change
    say_with_time "Backport transactions.sort_index default" do
      Transaction.where(sort_index: nil).select(:id).find_in_batches(batch_size: 50000).with_index do |batch, index|
        say("Processing batch #{index}\r", true)
        Transaction.where(id: batch).update_all(sort_index: 0)
      end
    end
    change_column_null :transactions, :sort_index, false
  end
end
