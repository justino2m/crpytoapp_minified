class ChangesCurrencyIdDefaultOnSymbolAliases < ActiveRecord::Migration[5.2]
  def change
    change_column_null :symbol_aliases, :currency_id, false
  end
end
