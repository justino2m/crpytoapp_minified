class SetNullFalseOnIgnoredInEntries < ActiveRecord::Migration[5.2]
  def change
    change_column_null :transactions, :ignored, false
    change_column_null :entries, :ignored, false
  end
end
