class AddGroupFieldsToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transactions, :group_name, :string
    add_column :transactions, :group_date, :datetime
    add_column :transactions, :group_from, :datetime
    add_column :transactions, :group_to, :datetime
    add_column :transactions, :group_count, :integer

    # Transaction.where(txsrc: 'Poloniex Lending', group_date: nil).each do |x|
    #   if x.entries.first.external_data.is_a?(Hash) && x.entries.first.external_data.dig('total_txns').present?
    #     x.group_date = x.date
    #     x.group_from = x.date
    #     x.group_to = x.date.end_of_day
    #     x.group_count = x.entries.first.external_data['total_txns'].to_i
    #     x.group_name = 'poloniex_lending'
    #     x.save!
    #   end
    # end
  end
end