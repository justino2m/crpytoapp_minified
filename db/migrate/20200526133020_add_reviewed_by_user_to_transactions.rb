class AddReviewedByUserToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transactions, :reviewed_by_user, :boolean
    change_column_default :transactions, :reviewed_by_user, from: nil, to: false
    say_with_time "Backport transactions.reviewed_by_user default" do
      Transaction.unscoped.select(:id).find_in_batches(batch_size: 50000).with_index do |batch, index|
        say("Processing batch #{index}\r", true)
        Transaction.unscoped.where(id: batch).where(reviewed_by_user: nil).update_all(reviewed_by_user: false)
      end
    end
    change_column_null :transactions, :reviewed_by_user, false
  end
end
