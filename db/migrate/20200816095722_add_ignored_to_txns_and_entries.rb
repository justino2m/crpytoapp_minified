class AddIgnoredToTxnsAndEntries < ActiveRecord::Migration[5.2]
  def change
    add_column :transactions, :ignored, :boolean, default: false
    add_column :entries, :ignored, :boolean, default: false

    # say_with_time "Backport transactions.ignored default" do
    #   Transaction.select(:id).find_in_batches(batch_size: 50000).with_index do |batch, index|
    #     say("Processing batch #{index}\r", true)
    #     Transaction.where(id: batch).update_all(ignored: false)
    #   end
    #   Transaction.where(label: 'ignored').update_all(ignored: true, label: nil)
    # end
    #
    # say_with_time "Backport entries.ignored default" do
    #   Entry.select(:id).find_in_batches(batch_size: 50000).with_index do |batch, index|
    #     say("Processing batch #{index}\r", true)
    #     Entry.where(id: batch).update_all(ignored: false)
    #   end
    # end
  end
end
