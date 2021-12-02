class AddTxhashImporterTagToEntries < ActiveRecord::Migration[5.2]
  def change
    add_column :entries, :txhash, :string
    add_column :entries, :importer_tag, :string
  end
end
